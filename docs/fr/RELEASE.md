# Publication

1. Merge des PR vers `main`
2. Release Please met à jour/ouvre une PR de release (version + CHANGELOG)
3. Merge de cette PR → tag + GitHub Release
4. Workflow de publication :
   - build `.gem`
   - push RubyGems (si `RUBYGEMS_API_KEY`)
   - push GitHub Packages
   - upload en asset
