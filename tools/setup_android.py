"""Fetch official Godot Android templates using ZIP range reads (no 1.3 GB download)."""
import io, os, pathlib, struct, urllib.request, zipfile, zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
SDK = pathlib.Path('E:/zadocs/godot/android-sdk')

def fetch(url, dest):
    dest = pathlib.Path(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        return
    print('Downloading', dest.name, flush=True)
    urllib.request.urlretrieve(url, dest)

def templates():
    target = pathlib.Path(os.environ['APPDATA'])/'Godot/export_templates/4.7.2.stable'
    if all((target/name).exists() for name in ('android_debug.apk','android_release.apk','version.txt')):
        return
    url = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
    def span(a, b):
        with urllib.request.urlopen(urllib.request.Request(url, headers={'Range': f'bytes={a}-{b}'}), timeout=120) as r:
            if r.status != 206:
                raise RuntimeError('Server did not honor range request')
            return r.read()
    size = int(urllib.request.urlopen(urllib.request.Request(url, method='HEAD')).headers['Content-Length'])
    tail = span(size - 65536, size - 1)
    end = tail.rfind(b'PK\x05\x06')
    eocd = struct.unpack('<4s4H2LH', tail[end:end+22])
    directory = span(eocd[6], eocd[6]+eocd[5]-1)
    pos = 0
    target = pathlib.Path(os.environ['APPDATA'])/'Godot/export_templates/4.7.2.stable'
    target.mkdir(parents=True, exist_ok=True)
    while directory[pos:pos+4] == b'PK\x01\x02':
        h = struct.unpack('<4s6H3L5H2L', directory[pos:pos+46])
        name = directory[pos+46:pos+46+h[10]].decode()
        if name.split('/')[-1] in ('android_debug.apk', 'android_release.apk', 'version.txt'):
            dest = target/name.split('/')[-1]
            if not dest.exists():
                print('Fetching template', name, h[8], flush=True)
                local = span(h[16], h[16]+29)
                lh = struct.unpack('<4s5H3L2H', local)
                start = h[16]+30+lh[9]+lh[10]
                compressed = span(start, start+h[8]-1)
                data = zlib.decompress(compressed, -15) if h[4] == 8 else compressed
                assert len(data) == h[9] and zlib.crc32(data) == h[7]
                dest.write_bytes(data)
                print('Installed', dest, flush=True)
        pos += 46+h[10]+h[11]+h[12]

if __name__ == '__main__':
    templates()
    SDK.mkdir(parents=True, exist_ok=True)
    for name, url, folder in [
        ('platform-tools.zip','https://dl.google.com/android/repository/platform-tools-latest-windows.zip',SDK),
        ('build-tools.zip','https://dl.google.com/android/repository/build-tools_r35.0.1_windows.zip',SDK/'build-tools'),
    ]:
        archive=SDK/name
        fetch(url,archive)
        with zipfile.ZipFile(archive) as z:
            z.extractall(folder)
    old=SDK/'build-tools/android-15'
    if old.exists() and not (SDK/'build-tools/35.0.1').exists():
        old.rename(SDK/'build-tools/35.0.1')
    print('Android dependencies ready', flush=True)
