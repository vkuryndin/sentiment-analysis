"""Keep Linux AMD64 native resources in the Docker-only Spring Boot JAR."""
import io
import sys
from pathlib import Path
from zipfile import ZipFile, ZIP_STORED


def slim_library(data, family):
    with ZipFile(io.BytesIO(data)) as source:
        names = source.namelist()
        if family == 'onnxruntime':
            required = ['libonnxruntime.so', 'libonnxruntime4j_jni.so']
            paths = [n for n in names if '/linux-x64/' in n and n.endswith('/' + required[0])]
            if len(paths) != 1:
                raise ValueError(f'Unexpected ONNX native layout: {paths}')
            root = paths[0].split('linux-x64/')[0]
            keep = root + 'linux-x64/'
        else:
            root = 'native/lib/'
            keep = root + 'linux-x86_64/cpu/'
            required = ['libtokenizers.so']
        for name in required:
            if keep + name not in names:
                raise ValueError(f'Missing required native resource: {keep}{name}')
        removed = [
            n for n in names
            if n.startswith(root)
            and n != root
            and n != root + 'tokenizers.properties'
            and not n.startswith(keep)
            and not keep.startswith(n)
        ]
        if not any(not n.endswith('/') for n in removed):
            raise ValueError(f'No foreign platform binaries found in {family}')
        if any(n.upper().startswith('META-INF/') and n.upper().endswith(('.SF', '.RSA', '.DSA', '.EC')) for n in names):
            raise ValueError(f'Cannot modify signed JAR: {family}')
        excluded = set(removed)
        out = io.BytesIO()
        with ZipFile(out, 'w') as target:
            target.comment = source.comment
            for info in source.infolist():
                if info.filename not in excluded:
                    target.writestr(info, source.read(info))
        result = out.getvalue()
        print(f'{family}: {len(data)} -> {len(result)} bytes; removed {len(removed)} entries')
        return result


def slim_boot_jar(source_path, target_path):
    families = {'BOOT-INF/lib/onnxruntime-1.20.0.jar': 'onnxruntime',
                'BOOT-INF/lib/tokenizers-0.39.0.jar': 'tokenizers'}
    with ZipFile(source_path) as source:
        if not families.keys() <= set(source.namelist()):
            raise ValueError('Expected ONNX Runtime and DJL dependencies not found')
        with ZipFile(target_path, 'w') as target:
            target.comment = source.comment
            for info in source.infolist():
                data = source.read(info)
                if info.filename in families:
                    data = slim_library(data, families[info.filename])
                # Spring Boot requires nested libraries to be stored, not deflated.
                if info.filename.startswith('BOOT-INF/lib/') and info.filename.endswith('.jar'):
                    info.compress_type = ZIP_STORED
                target.writestr(info, data)
    with ZipFile(target_path) as target:
        if target.testzip() is not None:
            raise ValueError('Invalid output JAR')
    print(f'Application JAR: {Path(source_path).stat().st_size} -> {Path(target_path).stat().st_size} bytes')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('Usage: slim-linux-jar.py INPUT.jar OUTPUT.jar')
    slim_boot_jar(sys.argv[1], sys.argv[2])
