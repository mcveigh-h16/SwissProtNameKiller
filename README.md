
# SwissProtNameKiller

`SwissProtKillName_driver.csh` with embedded `SwissProtKillName.pl`.

## Overview
The `.csh` driver script uses the embedded Perl script to:

1. Download a list of SwissProt accessions
2. Remove the locus name from all listed accessions
3. Reload an intermediate ASN.1-to-ID version
4. Use `ffdbx_mssql` to reset the fail flag on the new version of the same accession set, enabling loading of the new version

## Safety checks
The script checks whether any listed accessions are:

- suppressed
- withdrawn
- dead

If any are found, the script reports them and exits **without taking action**.  
You must resolve those accessions first (often temporary unsuppress/unwithdraw), then rerun the script.  
After completion, return affected accessions to suppress/withdraw status as needed.

## Requirements / Environment
- Correct indexer load settings and paths
- A `.y` file in the user?s home directory containing the user?s Sybase password
- Input accession file with one accession per line:
  - `acc_file_prefix.acc`

## Usage
Run with file prefix only (without `.acc`):

```bash
./SwissProtKillName_driver.csh acc_file_prefix
```

The script generates multiple output/debug files sharing the same prefix with different suffixes.  
These can help debug failures and validate edited ASN.1 output.

## Script location
Scripts are available in:

`/net/snowman/vol/export2/mcveigh/scripts`

## Notes
- Use `ffdbx_mssql` (not plain `ffdbx`)
- `FLATFILE` must be updated to `FLATFILE_NEW` throughout
- Some filenames are hard-coded; future improvement is to make these user-configurable
