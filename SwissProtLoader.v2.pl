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

my ($retval) = 0;

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


$retval = idstat1($in_filename,$tmp_idstatchk);
if ($retval != 1) {
    print STDERR "$0 : Error : unexpected return value from idstat1 subroutine : $retval";
    exit(10);
}
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
    my ($acc_file,$idstat_file) = @_;
    my ($sub_name) = (caller(0))[3];
    my @tokens();
    my @problem_accs();

    if ($acc_file eq "" || $idstat_file eq "") {
	print STDERR "$0 : Error : $sub_name : accession or idstat output file arguments are empty\n";
	return 0;
    }

    system ("idstat -A $acc_file -mr -nh -r F > $idstat_file");
    if ($? != 0) {
	print STDERR "$0 : Error : $sub_name : system call for idstat failed\n";
	return -1;
    }
    if (! open(IDSTATFILE, "<$idstat_file")) {
	print STDERR "$0 : Error : $sub_name : open failed for file $idstat_file\n";
	return -2;
    }
    while(<IDSTATFILE>) {
	@tokens = split(/\s+/);
	unless ($tokens[6] eq 'No' && $tokens[7] eq 'No') {
	    push(@problem_accs,$tokens[0]);
	}
    }
    close(IDSTATFILE);

    if (@problem_accs) {
	print STDOUT "$0 : Error : $sub_name : Some accessions are withdrawn or suppressed:\n";
	foreach (@problem_accs) {
	    print STDOUT "$_ ";
	}
	print STDOUT "\n";
	return -3;
    }
    return 1;
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

  
  if (! open(SE2BSS_FILE, "<$se2bss_asn1_file")) {
      print STDERR "$0 : Error : $sub_name : open failed for file $se2bss_asn1_file\n";
      return -10;
  }
  if (! open(FIXASN_FILE, ">$fix_asn1_file")) {
      print STDERR "$0 : Error : $sub_name : open failed for file $fix_asn1_file\n";
      return -11;
  }
  while(<SE2BSS_FILE>) {
      chomp;
      $line1 = $_;

      if ($line1 =~ /^\s+swissprot \{$/) {
	  print FIXASN_FILE "$line1\n";

	  $line2 = <SE2BSS_FILE>;
	  chomp($line2);

	  if ($line2 =~ /^\s+name \"\w+\" ,$/) {
	      # No-op : Don't print the SP name identifier
	  }
	  else {
	      print FIXASN_FILE "$line2\n";
	  }
      }
      else {
	  print FIXASN_FILE "$line1\n";
      }
  }
  close(SE2BSS_FILE);
  close(FIXASN_FILE);

}

######################################################################
#Load the intermediate file with striped locus names to id.
#Report any errors found and run idstat to confirm load
######################################################################
sub LoadIntermediate
{


  # Investigate setting up the %ENV hash ?
  # That might work (for subsequent idload.pl call) for a single env variable, like this one:

  $ENV{"IDLOADSEQENTRY"} = "idloadseqentry -O AllowGiFarPtr,AllowSought,AcceptSeqVer,IgnoreDeadHistory,IgnoreInvalidHist";

  # But... I don't know about this!
  system ("source /am/ncbiapdata/database_env/id_env.csh");

  # Let's see what ID-related variables now exist in the environment
  system ("printenv | grep ID");


  # This won't work as-is because of internal double quotes:
  # system ("setenv IDLOADSEQENTRY "idloadseqentry -O AllowGiFarPtr,AcceptDate,AllowGiFarPtr,AllowSought,AcceptSeqVer,IgnoreDeadHistory,IgnoreInvalidHist");


  ## system ("idload.pl -a $tmp_intermediatefile -d `pwd` -l `pwd`/idload -P till1620 -o SWISSPROT");

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
