"""
Opens recommended asset pages in your browser for manual legal downloads.
This intentionally avoids bulk API downloading. Poly Haven assets are CC0, but their public API has separate usage terms.
For commercial projects, manual asset-page downloads or their official add-on/workflow is safer than blind API scraping.
"""
import json, webbrowser, pathlib, time

manifest = pathlib.Path(__file__).with_name('asset_manifest_recommended_sources.json')
data = json.loads(manifest.read_text(encoding='utf-8'))
urls = []
for group in ['hdri_lighting', 'polyhaven_pbr', 'dem_sources']:
    for item in data.get(group, []):
        urls.append(item['page'])

print('Opening', len(urls), 'recommended source pages...')
for url in urls:
    print(url)
    webbrowser.open(url)
    time.sleep(0.25)
