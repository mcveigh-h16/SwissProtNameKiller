#!/usr/bin/perl

######################################################################
#SwissProtLoader.pl
#script to fix SwissProt accessions that will not load due to locus name collisions
#SwissProt likes to swap locus names between accessions but we link the locus name and the
#accession so these frequently fail to load when it's a simple swap. 
#In put file is a list of accessions to be loaded one accession per line.
######################################################################

use strict;

my $in_filename;
#my $out_filename;
my $thisline;
my $accession;

my $tmp_idstatchk = "tmp.idstat_output.txt";

my $tmp_asn1file;
my $tmp_intermediatefile;
my $tmp_asn1bioseq;
my @linelist;

$in_filename = shift || die "You must specify an input filename! The input file should contain a list accessions to be loaded, one accession per line\n";
#$out_filename = shift || die "You must specify a input filename and output file name!\n";

open (INFILE, $in_filename) || die "Unable to open $in_filename!\n";
#open (OUT, ">$out_filename") || die "Unable to open $out_filename!\n";

while ($thisline = <INFILE>) {
  #get rid of the carriage return
  $thisline =~ s/\r//;
  $thisline =~ s/\n//;
  $thisline =~ s/\"//g;
}


&idstat1;
&FixAsn1;
&LoadIntermediate;
&ResetFailFlag;

close (INFILE);
close (OUTFILE);

######################################################################
#idstat to check for withdrawn or suppressed accessions before we do anything
#NOTE all suppressed and withdrawn sequences need to be unsuppressed or unwithdrawn
#before the script will work correctly
######################################################################

#maybe skip this and do it outside of the script

sub idstat1
{
my @tokens;

  system ("idstat -A INFILE -mr >> $tmp_idstatchk")
  while ($thisline = <$tmp_idstatchk) {
  @tokens = split(/\t/, $thisline);
    if ($token[6] =~ Yes) {  
    print ERROR 
    }
  }

}


######################################################################
#Download current asn.1 and create bio-seq set
#Remove the offending locus name from the asn.1
#save intermediate asn.1 to a temp file
######################################################################
sub FixAsn1
{
  system ("seqfetch -G INFILE -o $tmp_asn1file");
  system ("se2bss -i $tmp_asn1file -o $tmp_asn1bioseq");
  open (OUT, $tmp_intermediatefile) || die "Unable to open $tmp_intermediatefile for writing!\n";
  while ($thisline = <$tmp_asn1bioseq>) {
     if ($thisline =~ /swissprot\nline1/name/) {
     print OUT $thisline;
     # now need to figure out how to check the next line and selectively skip it
     } else {
     print OUT $thisline;
     }
  }
}

######################################################################
#Load the intermediate file with striped locus names to id.
#Report any errors found and run idstat to confirm load
######################################################################
sub LoadIntermediate
{
  system ("source /am/ncbiapdata/database_env/id_env.csh");
  system ("setenv IDLOADSEQENTRY "idloadseqentry -O AllowGiFarPtr,AcceptDate,AllowGiFarPtr,AllowSought,AcceptSeqVer,IgnoreDeadHistory,IgnoreInvalidHist");
  system ("idload.pl -a $tmp_intermediatefile -d `pwd` -l `pwd`/idload -P till1620 -o SWISSPROT");
  #maybe do idstat now and ask user to check before proceeding?
}

######################################################################
#Reset fail flag for accessions in processing queue so the new version can load
######################################################################
sub ResetFailFlag
{
  system ("setenv LD_LIBRARY_PATH /netopt/Sybase/clients/12.0-EBF9209/lib");
  system ("ffdbx -i INFILE -d ftds -m q -S FLATFILE_NEW -s swissprot -T UPDATE -U mcveigh -P till1620");
}
