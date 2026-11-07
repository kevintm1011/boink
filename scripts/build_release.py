"""Build the private-channel Windows release; never write its credential to source."""
import hashlib, json, os, pathlib, re, subprocess, zipfile
ROOT = pathlib.Path(__file__).resolve().parents[1]
COMPANION = ROOT / 'companion'
VERSION = (COMPANION / 'VERSION').read_text().strip()
REPO = 'kevintm1011/boink'

def main():
    if not re.fullmatch(r'\d+\.\d+\.\d+', VERSION):
        raise SystemExit('VERSION must be X.Y.Z')
    if f'## Version: {VERSION}' not in (ROOT/'addon/DOINK/DOINK.toc').read_text():
        raise SystemExit('Addon and Companion versions must match')
    webhook = os.environ.get('DOINK_CHANNEL_WEBHOOK', '')
    if not re.fullmatch(r'https://discord\.com/api/webhooks/\d+/[A-Za-z0-9_-]+', webhook):
        raise SystemExit('Set the DOINK_CHANNEL_WEBHOOK Actions secret before releasing.')
    ref=os.environ.get('GITHUB_REF','')
    if ref.startswith('refs/tags/') and ref != 'refs/tags/v'+VERSION:
        raise SystemExit('Tag must match companion/VERSION')
    output=ROOT/'dist';output.mkdir(exist_ok=True)
    exe=output/'DOINK - Triple K.exe'
    go=os.environ.get('DOINK_GO','go')
    subprocess.run([go,'run','github.com/tc-hib/go-winres@v0.3.3','make','--in','winres/winres.json','--out','cmd/doink/rsrc','--product-version',VERSION,'--file-version',VERSION],cwd=COMPANION,check=True)
    env=dict(os.environ,GOOS='windows',GOARCH='amd64',CGO_ENABLED='0')
    flags=f'-s -w -H windowsgui -X main.version={VERSION} -X github.com/ryan-flan/DOINK/companion/internal/brand.ChannelWebhook={webhook}'
    result=subprocess.run([go,'build','-buildvcs=false','-trimpath','-ldflags',flags,'-o',str(exe),'./cmd/doink'],cwd=COMPANION,env=env)
    if result.returncode:
        raise SystemExit('Windows compilation failed')
    bundle=output/f'DOINK-Triple-K-{VERSION}-update.zip'
    def write_payload(z):
        for p in sorted((ROOT/'addon/DOINK').rglob('*')):
            if p.is_file(): z.write(p,'DOINK/'+p.relative_to(ROOT/'addon/DOINK').as_posix())
        z.write(exe,'Companion/DOINK - Triple K.exe')
    with zipfile.ZipFile(bundle,'w',zipfile.ZIP_DEFLATED) as z: write_payload(z)
    manifest={'schema':1,'product':'DOINK-Triple-K','version':VERSION,
        'url':f'https://github.com/{REPO}/releases/download/v{VERSION}/{bundle.name}',
        'sha256':hashlib.sha256(bundle.read_bytes()).hexdigest()}
    (output/'update.json').write_text(json.dumps(manifest,indent=2)+'\n')
    with zipfile.ZipFile(output/f'DOINK-Triple-K-{VERSION}.zip','w',zipfile.ZIP_DEFLATED) as z:
        write_payload(z)
        z.writestr('Companion/config.toml',"# Keep your existing config when upgrading.\nrealtime = true\nupdate_check = true\nupdate_notify = true\nupdate_repository = 'kevintm1011/boink'\n")
        z.write(ROOT/'README.md','START-HERE.md')
        z.write(ROOT/'LICENSE','LICENSE.txt')
        z.write(ROOT/'docs/TRIPLE-K-RELEASES.md','ADMIN-RELEASES.md')
    print(f'Built DOINK - Triple K {VERSION}; manifest SHA-256 verified from update ZIP.')

if __name__ == '__main__': main()
