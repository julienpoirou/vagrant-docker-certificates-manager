# Release

1. Merge feature PRs into `main`
2. Release Please updates/opens Release PR (version + CHANGELOG)
3. Merge Release PR → tag + GitHub Release
4. Publish workflow:
   - build `.gem`
   - push to RubyGems (if `RUBYGEMS_API_KEY`)
   - push to GitHub Packages
   - upload asset to Release
