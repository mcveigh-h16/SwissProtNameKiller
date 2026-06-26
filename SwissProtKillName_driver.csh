#!/bin/csh

# Hard-coded variables

set id_user = $USER
set id_pwfile = /home/$USER/.y
set id_pswd = `cat $id_pwfile`
set id_loader_dir = IdLoad

#------------------------------------------------------------------
# Argument handling.
#------------------------------------------------------------------

if ($1 == "" ) then
        echo ""
        echo "Usage: $0 : Fname_Prefix"
        echo ""
        echo "  Fname_Prefix : Filename prefix used for all files related to"
	echo "                 killing the Name/Locus-Name identifier for a"
	echo "                 set of SwissProt records."
	echo ""
        echo "Note: A file of SwissProt accession numbers, one per line,"
	echo "with the same prefix, and a suffix of .acc, must exist!"
        echo ""
        exit 1
endif

set sp_fname_prefix = "$1"
set acc_file = $sp_fname_prefix.acc

if (! -e $acc_file) then
    echo "$0 : USAGE : an accession number file named $acc_file must exist"
    exit 1
endif

#------------------------------------------------------------------
# Environmental stuff.
#------------------------------------------------------------------

set path = ( /net/idflow02/export/d0/gbutils $path )
set path = ( /netopt/genbank/subtool/bin $path )

source /am/ncbiapdata/database_env/id_env.csh
#setenv IDLOADSEQENTRY "idloadseqentry -O TrialNoLoad,AllowGiFarPtr,AcceptDate,AllowSought,AcceptSeqVer,IgnoreDeadHist,IgnoreInvalidHist,IgnoreVerFarPtr"
setenv IDLOADSEQENTRY "idloadseqentry -O AllowGiFarPtr,AcceptDate,AllowSought,IgnoreDeadHist,IgnoreInvalidHist,IgnoreVerFarPtr"

#------------------------------------------------------------------
# Main tasks follow...
#------------------------------------------------------------------

# $sp_fname_prefix is a filename prefix used for all
# data files (accession list, idstat output, ASN.1 files).
# The below perl script has hard-coded suffixes for each
# type of file that it generates: .acc for the accession
# file, .fixed for the final ASN.1 file, etc. The ID-load
# step needs to know the name of that final ASN.1 file, 
# and we're hard-coding it here. This is a complete HACK
# and should be fixed!

set orig_asn1_file = $sp_fname_prefix.orig
set fix_asn1_file = $sp_fname_prefix.fixed

./SwissProtKillName.pl $sp_fname_prefix
set retval = $status
if ($retval != 0) then
    echo "$0 : FATAL : Non-zero status from SwissProtKill.pl : retval = $retval : acc file = $sp_acc_file : fname prefix = $sp_fname_prefix"
    exit 10
else if (! -s $fix_asn1_file) then
    echo "$0 : FATAL : fixed ASN.1 file not found after SwissProtKill.pl : $fix_asn1_file"
    exit 15
endif

# Query user if the diff results are ok?
diff $orig_asn1_file $fix_asn1_file

if (! -d $id_loader_dir) then
    mkdir $id_loader_dir
endif

idload.pl -a $fix_asn1_file -d `pwd` -l `pwd`/$id_loader_dir -P $id_pswd -o SWISSPROT
set retval = $status
if ($retval != 0) then
    echo "$0 : FATAL : Non-zero ID-load status : retval = $retval : file = $fix_asn1_file : one or more of the SP records might not have loaded"
    exit 20
endif







#ffdbx -d ftds -S FLATFILE_NEW -m q -s sprot -i $acc_file
ffdbx -d ftds -S FLATFILE_NEW -m q -s sprot -i $acc_file -U gbupdate -P gbupdate_ps
set retval = $status
if ($retval != 0) then
    echo "$0 : FATAL : Non-zero ffdbx_mssql status : retval = $retval : file $acc_file : records might not be flagged properly in the PQ"
    exit 30
endif

exit 0
