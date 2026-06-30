import glob
import os
import zipfile

cache = os.path.expanduser("~/flutter_linux/bin/cache")
for z in glob.glob(os.path.join(cache, "dart-sdk*.zip")):
    with zipfile.ZipFile(z) as zf:
        zf.extractall(cache)
    print("extracted", z)
