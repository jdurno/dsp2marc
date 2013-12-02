#!/usr/bin/perl

################################################################################
# Convert DSP XML to MARC format
# J. Durno
# Last Modified: 2013.12.02
# 
################################################################################


use strict;
use XML::Simple;
#use Data::Dumper;
use Encode::Escape;
use MARC::Record;
use DBI;

################################################################################
# mysql connection info
my $mysql_db = "dspurls";
my $mysql_user = "xxx";
my $mysql_pass = "xxx";
my $mysql_host = "localhost";
our $dbh = DBI->connect("DBI:mysql:$mysql_db:$mysql_host", $mysql_user, $mysql_pass);

################################################################################

		
my @filenames = (
		'Approved_Monographs_Electronic_Bilingual_2209',
		'Approved_Monographs_Electronic_English_12716',
		'Approved_Monographs_Electronic_English_384',
		'Approved_Monographs_Electronic_French_12172',
		'Approved_Monographs_Electronic_French_360',
		'Approved_Mono-Serial_Electronic_Bilingual_25',
		'Approved_Mono-Serial_Electronic_French_606',
		'Approved_PeriodicalIssues_Electronic_Bilingual_309',
		'Approved_PeriodicalIssues_Electronic_Bilingual_8154',
		'Approved_PeriodicalIssues_Electronic_English_784',
		'Approved_PeriodicalIssues_Electronic_French_19489',
		'Approved_PeriodicalIssues_Electronic_French_786',
		'Approved_SeriesIssues_Electronic_Bilingual_218',
		'Approved_SeriesIssues_Electronic_Bilingual_3928',
		'Approved_SeriesIssues_Electronic_English_17955',
		'Approved_SeriesIssues_Electronic_English_549',
		'Approved_SeriesIssues_Electronic_French_14244',
		'Approved_SeriesIssues_Electronic_French_418'	
		);

#need to convert some of the language codes to MARC equivs 
my %languageTable = (
        'alb/sqi' => 'alb',
        'chi/zho' => 'chi',
        'dut/nld' => 'dut',
        'fre/fra' => 'fre',
        'ger/deu' => 'ger',
        'gre/ell' => 'gre',
        'hvr/scr' => 'hvr',
        'id' => 'ind',
        'inq' => 'iku',
        'pa' => 'pan',
        'per/fas' => 'per',
        'ron/rum' => 'rum',
        'srp/scc' => 'srp',
        'tl' => 'tgl'
    );

my $filename;

foreach $filename (@filenames) {

	my $fileInMemory;
	my $infile = $filename . '.xml';
	my $outfile_mrc = "./MARC/$filename" . '.mrc';
	my $outfile_txt = "./TEXT/$filename" . '.txt';
	my $gocLog = 'gocLog.txt';
	
	
	my $publications = XMLin($infile, KeyAttr => ['publications'=>'publication']);
	
	open (OUTFILETXT, ">$outfile_txt") || die "couldn't open $outfile_txt for write: $!";
	open (OUTFILEMRC, ">$outfile_mrc") || die "couldn't open $outfile_mrc for write: $!";
	open (GOCLOG, ">>$gocLog") || die "couldn't open $gocLog for append: $!";
	
	my $counter = 0;
	
	MARCPROCESSOR:
	foreach my $publication (@{$publications->{publication}}) {
		
		# uncomment if only want first ~25 records from each file
		#last MARCPROCESSOR if $counter == 25;
		
		## Create a MARC::Record object.
		my $record = MARC::Record->new();
		$record->encoding('UTF-8');
		
		
		
		my $noTitleFlag = 1;
		
		my $serialFlag = 0;
	
	
	
		########## Type of Publication: ##########
		#As per Nancy: make them all monographs, no matter what
		
		my $leader = $record->leader();
		substr($leader,5,1) = 'n'; #new record
		substr($leader,6,1) = 'a'; #positions 6-7 indicate monograph ('am')
		substr($leader,7,1) = 'm';
		$record->leader($leader);
		
		########## MARC 007 ##########
		
		my $MARC007 = 'cr |||||||||||';
		$record->append_fields( MARC::Field->new('007', $MARC007));
		
		print OUTFILETXT "007: $MARC007";
	
		
		########## MARC 008 ##########
	
		my @t = localtime;	
		$t[5] -= 100;
		$t[4]++;
		
		#positions 00-05
		my $MARC008 = sprintf "%02d%02d%02d", @t[5,4,3];
		
		my $publicationYearFrom008 = 0;
		#positions 06-14
		if ($publication->{publicationYear}->{content}) {
			$publicationYearFrom008 = $publication->{publicationYear}->{content};
			$MARC008 .= 's' . &fix_string ($publication->{publicationYear}->{content}) . '||||'; #single known date, year of pub.
		} else {
			$MARC008 .= '|||||||||'; #no attempt to code, 9 spaces
		}
		
		#positions 15-17
		$MARC008 .= 'xxc'; #Canada country of publication
		
		#positions 18-22
		$MARC008 .= '|||||'; #no attempt to code, 5 spaces
		
		#position 23
		$MARC008 .= 'o'; #format of publication - online
		
		#position 24-27
		$MARC008 .= '||||';  #no attempt to code, 4 spaces
		
		#position 28
		$MARC008 .= 'f'; #federal government publication
		
		#position 29
		$MARC008 .= '|'; #no attempt to code
		
		#position 30
		$MARC008 .= '|'; #no attempt to code
		
		#position 31
		$MARC008 .= '|'; #no attempt to code
		
		#positions 32, 33, 34
		
		$MARC008 .= '|||'; #no attempt to code, 3 spaces
		
		#positions 35, 36, 37 [Language of publication]
		
		my $foundEnglish = 0;
		my $foundFrench = 0;
		
		my %languagesOfPublication;
		if (ref($publication->{languageOfPublication}) eq "HASH") {
		
			if ($publication->{languageOfPublication}->{isoCode}) {
				my $lang = $publication->{languageOfPublication}->{isoCode};
				
				#can't code for 'miscellaneous'
				unless ($lang eq 'mis') {
				
					if (exists($languageTable{$lang})) {
						$languagesOfPublication{ $languageTable{$lang} } = 1;
					} else {
						
						$languagesOfPublication{ $lang } = 1;	
						
					}
				
				}
			}
			
		} elsif (ref($publication->{languageOfPublication}) eq "ARRAY") {
			
			if ($publication->{languageOfPublication}) {
				foreach my $languageOfPublication (@{$publication->{languageOfPublication}}) {
					my $lang = $languageOfPublication->{isoCode};
					
					#can't code for 'miscellaneous'
					unless ($lang eq 'mis') {
					
						if (exists($languageTable{$lang})) {
							$languagesOfPublication{ $languageTable{$lang} } = 1;
						} else {
							$languagesOfPublication{ $lang } = 1;		
						}
					
					}
					
				}	
			}	
		}
		
		my $numberOfLanguages = scalar(keys %languagesOfPublication);
		
		my $pos35 = 0;
		
		if ($numberOfLanguages < 1) {
			$MARC008 .= '|||';
		} elsif ($numberOfLanguages > 1) {
			
			if (exists($languagesOfPublication{'eng'})){
				$MARC008 .= 'eng';
				$pos35 = 'eng';
			} else {		
				$MARC008 .= 'mul';
				$pos35 = 'mul';
			}
			
		} else {
			
			$MARC008 .= ((keys %languagesOfPublication)[0])	
		}
		
		
		
		#position 38
		$MARC008 .= '|'; #no attempt to code
		
		#position 39
		$MARC008 .= '|'; #no attempt to code
		
		$record->append_fields( MARC::Field->new('008', $MARC008));
		
		print OUTFILETXT "008: $MARC008";	
		
		######### 020: ISBN #########
		if (ref($publication->{isbn}) eq "HASH") {
		
			if ($publication->{isbn}->{content}) {
				my $isbnContent = &fix_string ($publication->{isbn}->{content});
				print OUTFILETXT 'ISBN [020 ## |a]: ' . $isbnContent;
				$record->append_fields( MARC::Field->new('020', ' ', ' ', a => $isbnContent));
				
			}	
		} elsif (ref($publication->{isbn}) eq "ARRAY") {
			if ($publication->{isbn}) {
				foreach my $isbn (@{$publication->{isbn}}) {
					if ($isbn->{lang} eq 'eng') {
						my $isbnContent = &fix_string ($isbn->{content});
						print OUTFILETXT 'ISBN [020 ## |a]: ' . $isbnContent;
						$record->append_fields( MARC::Field->new('020', ' ', ' ', a => $isbnContent));
					}
				}	
			}	
		}
	
		######### 022: ISSN #########
		if (ref($publication->{issn}) eq "HASH") {
		
			if ($publication->{issn}->{content}) {
				my $issnContent = &fix_string ($publication->{issn}->{content});
				print OUTFILETXT 'ISSN [022 ## |a]: ' . $issnContent;
				$record->append_fields( MARC::Field->new('022', ' ', ' ', a => $issnContent));
				
			}	
		} elsif (ref($publication->{issn}) eq "ARRAY") {
			if ($publication->{issn}) {
				foreach my $issn (@{$publication->{issn}}) {
					if ($issn->{lang} eq 'eng') {
						my $issnContent = &fix_string ($issn->{content});
						print OUTFILETXT 'ISSN [022 ## |a]: ' . $issnContent;
						$record->append_fields( MARC::Field->new('022', ' ', ' ', a => $issnContent));
					}
				}	
			}	
		}
		
		
		
		########## 024: eBookstoreIdentifier #########
		
		if ($publication->{eBookstoreIdentifier}->{content}) {
			my $eBookstoreIdentifierContent = &fix_string ($publication->{eBookstoreIdentifier}->{content});
			print OUTFILETXT 'Ebookstore Identifier [024 8# |a]: ' . $eBookstoreIdentifierContent;
			$record->append_fields( MARC::Field->new('024', '8', ' ', a => $eBookstoreIdentifierContent));
			
		}
	
		########## 040: Language of MARC Record #########
		#Records are /always/ English
		print OUTFILETXT 'Language of MARC record [040 ## |b]: eng';
		$record->append_fields( MARC::Field->new('040', ' ', ' ', b => 'eng'));
		
		
		########## 041: Language of Publication #########
		# Only for bilingual publications
		# see 008[35-37] above
		# Format: 041 	1#$aeng$afre 
		if ($numberOfLanguages > 1) {
			my $textOutput = 'Bilingual [041 1# |a]:';
			my @marcOutput = ('041', '1', ' ');
			if ($pos35) {
				push(@marcOutput, a => $pos35);	
			}
			
			foreach my $lang (keys %languagesOfPublication) {
				$textOutput .= "$lang ";
				unless (($pos35 eq 'eng') && ($lang eq 'eng')) {
					my %langhash;
					$langhash{'a'} = $lang;
					push (@marcOutput, %langhash);
				}
			}
			
			print OUTFILETXT  $textOutput;
			$record->append_fields( MARC::Field->new(@marcOutput));				
		}
		
		
		########## 086: Government of Canada Catalogue Number #########
		
		if ($publication->{gocCatalogueNumber}->{content}) {
			my $gocCatalogueNumberContent = &fix_string ($publication->{gocCatalogueNumber}->{content}); 
			print OUTFILETXT 'goc Number [086 1# |a]: ' . $gocCatalogueNumberContent;
			$record->append_fields( MARC::Field->new('086', '1', ' ', a => $gocCatalogueNumberContent));
			
		}
		
		##########110: Committee Header ######### 
		
		if ($publication->{committeeHeader}) {
			foreach my $committeeHeader (@{$publication->{committeeHeader}}) {
				if ($committeeHeader->{lang} eq 'eng') {
					my $committeeHeaderContent = &fix_string ($committeeHeader->{content});
					print OUTFILETXT 'Committee Header [110 2# |a]: ' . $committeeHeaderContent;
					$record->append_fields( MARC::Field->new('110', '2', ' ', a => $committeeHeaderContent));
					
				}
			}
			
		}
	
	
		######### 245: Title #########
		#title will be in one of title, seriesTitle, or committeeTitle elements
		if ($publication->{title}) {
			
			foreach my $title (@{$publication->{title}}) {
				
				if ($title->{lang} eq 'eng') {
					my $titleContent = &fix_string ($title->{content});
					my $initialArticle = &count_initial_article ($titleContent);			
					$noTitleFlag = 0; 
				
				
					my $subtitleContent = 0;
					
					if ($publication->{subtitle}) {
						foreach my $subtitle (@{$publication->{subtitle}}) {
							if ($subtitle->{lang} eq 'eng') {
								$subtitleContent = &fix_string ($subtitle->{content});
								
							} 								
						} 
					}
					
					if ($subtitleContent) {
						print OUTFILETXT 'Title [eng] [245 1' . $initialArticle . '|a]: ' . $titleContent . '|b]: ' . $subtitleContent;
						unless ($record->title()) {
							$record->append_fields( MARC::Field->new('245', '1', $initialArticle , a => $titleContent . ' ', h => '[electronic resource]' . ': ',  b => $subtitleContent ));
						}
						
					} else {
						print OUTFILETXT 'Title [eng] [245 1' . $initialArticle . '|a]: ' . $titleContent;
						unless ($record->title()) {
							$record->append_fields( MARC::Field->new('245', '1', $initialArticle , a => $titleContent . ' ', h => '[electronic resource]'));
						}
						
					}
				
				} 
			}
	
			
			
		} elsif ($publication->{seriesTitle}) {
			foreach my $seriesTitle (@{$publication->{seriesTitle}}) {
				
				if ($seriesTitle->{lang} eq 'eng') {
					my $titleContent = &fix_string ($seriesTitle->{content});
					my $initialArticle = &count_initial_article ($titleContent);
					print OUTFILETXT 'Title [eng] [245 1' . $initialArticle . '|a]: ' . $titleContent;
					$noTitleFlag = 0; 
				
				
					my $subtitleContent = 0;
					
					if ($publication->{seriesSubtitle}) {
						foreach my $subtitle (@{$publication->{seriesSubtitle}}) {
							if ($subtitle->{lang} eq 'eng') {
								$subtitleContent = &fix_string ($subtitle->{content});
								
							} 								
						} 
					}
					
					if ($subtitleContent) {
						print OUTFILETXT 'Title [eng] [245 1' . $initialArticle . '|a]: ' . $titleContent . '|b]: ' . $subtitleContent;
						unless ($record->title()) {
							$record->append_fields( MARC::Field->new('245', '1', $initialArticle , a => $titleContent . ' ', h => '[electronic resource]' . ': ', b => $subtitleContent . ' '));
						}
						
					} else {
						print OUTFILETXT 'Title [eng] [245 1' . $initialArticle . '|a]: ' . $titleContent;
						unless ($record->title()) {	
							$record->append_fields( MARC::Field->new('245', '1', $initialArticle , a => $titleContent . ' ', h => '[electronic resource]'));
						}
						
					}
				
				} 
			
			
			}	
			
				
		} elsif ($publication->{committeeTitle}) {
			foreach my $committeeTitle (@{$publication->{committeeTitle}}) {	
				if ($committeeTitle->{lang} eq 'eng') {
					my $titleContent = &fix_string ($committeeTitle->{content});
					my $initialArticle = &count_initial_article ($titleContent);
					print OUTFILETXT 'Title [eng] [245 1' . $initialArticle . '|a]: ' . $titleContent;
					unless ($record->title()) {
						$record->append_fields( MARC::Field->new('245', '1', $initialArticle , a => $titleContent . ' ', h => '[electronic resource]'));
					}
					$noTitleFlag = 0;
				}
				
			}	
			
				
		} 
	
		########## 250: Edition Statement ######### 
	
		if (ref($publication->{editionStatement}) eq "HASH") {
			
			if ($publication->{editionStatement}->{content}) {
				my $editionStatementContent = &fix_string ($publication->{editionStatement}->{content});
				print OUTFILETXT 'Edition Statement [250 ## |a]: ' . $editionStatementContent;
				$record->append_fields( MARC::Field->new('250', ' ', ' ', a => $editionStatementContent));
			
			}
			
		} elsif (ref($publication->{editionStatement}) eq "ARRAY") {
			foreach my $editionStatement (@{$publication->{editionStatement}}) {
				if ($editionStatement->{lang} eq 'eng') {
					my $editionStatementContent = &fix_string ($editionStatement->{content});
					print OUTFILETXT 'Edition Statement [250 ## |a]: ' . $editionStatementContent;
					$record->append_fields( MARC::Field->new('250', ' ', ' ', a => $editionStatementContent));
					
				}
			}
			
		}
		
		
		
		######### 260: Publisher, Place of Publication, and Date of Publication #########
	
	
		my $placeOfPublicationContent = 0;
		if ($publication->{placeOfPublication}->{content}) {
			$placeOfPublicationContent = &fix_string ($publication->{placeOfPublication}->{content});
			
			$placeOfPublicationContent =~ s/\s-.*$//;
			
			print OUTFILETXT 'Place of publication [260 ## |a]: ' . $placeOfPublicationContent;
				
		}	
		
		my $leadDepartmentContent = 0;
		if ($publication->{leadDepartment}) {
			foreach my $leadDepartment (@{$publication->{leadDepartment}}) {
				if ($leadDepartment->{lang} eq 'eng') {
					$leadDepartmentContent = &fix_string ($leadDepartment->{content});
					print OUTFILETXT 'Lead Department [260 ## |b]: ' . $leadDepartmentContent;				
				}
			}
			
		}
	
		my $dateOfPublicationContent = 0;
		if ($publication->{dateOfPublication}) {
			foreach my $dateOfPublication (@{$publication->{dateOfPublication}}) {
				if ($dateOfPublication->{lang} eq 'eng') {
					$dateOfPublicationContent = &fix_string ($dateOfPublication->{content});
					print OUTFILETXT 'Date of publication [260 ## |c]: ' . $dateOfPublicationContent;				
				}
			}
			
		} elsif ($publicationYearFrom008) {
			$dateOfPublicationContent = &fix_string ($publicationYearFrom008);
			print OUTFILETXT 'Date of publication [260 ## |c]: ' . $dateOfPublicationContent;			
		}
		
		if ($placeOfPublicationContent && $dateOfPublicationContent && $leadDepartmentContent) {		
			$record->append_fields( MARC::Field->new('260', ' ', ' ', a => $placeOfPublicationContent . ' : ', b => $leadDepartmentContent . ', ', c => $dateOfPublicationContent));		
		} elsif ($placeOfPublicationContent && $leadDepartmentContent) {
			$record->append_fields( MARC::Field->new('260', ' ', ' ', a => $placeOfPublicationContent . ' : ', b => $leadDepartmentContent));
		} elsif ($dateOfPublicationContent && $leadDepartmentContent) {
			$record->append_fields( MARC::Field->new('260', ' ', ' ', b => $leadDepartmentContent . ', ', c => $dateOfPublicationContent));
		} elsif ($placeOfPublicationContent && $dateOfPublicationContent) {
			$record->append_fields( MARC::Field->new('260', ' ', ' ', a => $placeOfPublicationContent . ', ', c => $dateOfPublicationContent));
		} elsif ($placeOfPublicationContent) {
			$record->append_fields( MARC::Field->new('260', ' ', ' ', a => $placeOfPublicationContent));
		} elsif ($leadDepartmentContent) {
			$record->append_fields( MARC::Field->new('260', ' ', ' ', b => $leadDepartmentContent));
		} elsif ($dateOfPublicationContent) {
			$record->append_fields( MARC::Field->new('260', ' ', ' ', c => $dateOfPublicationContent));
		}
			
	
		
		
	
		######### 300: Pagination Description and Collation #########
		
		my $paginationDescriptionContent = 0;
		if (ref($publication->{paginationDescription}) eq "HASH") {
		
			if ($publication->{paginationDescription}->{content}) {
				$paginationDescriptionContent = &fix_string ($publication->{paginationDescription}->{content});
				print OUTFILETXT 'Pagination Description [300 ## |a]: ' . $paginationDescriptionContent;
				
				
			}
			
		} elsif (ref($publication->{paginationDescription}) eq "ARRAY") {
			
			if ($publication->{paginationDescription}) {
				foreach my $paginationDescription (@{$publication->{paginationDescription}}) {
					if ($paginationDescription->{lang} eq 'eng') {
						$paginationDescriptionContent = &fix_string ($paginationDescription->{content});
						print OUTFILETXT 'Pagination Description [300 ## |a]: ' . $paginationDescriptionContent;
							
					}
				}	
			}	
		}
		
		my $collationContent = 0;
		if (ref($publication->{collation}) eq "HASH") {
		
			if ($publication->{collation}->{content}) {
				$collationContent = &fix_string ($publication->{collation}->{content});
				print OUTFILETXT 'Collation [300 ## |b]: ' . $collationContent;
				
			}	
		} elsif (ref($publication->{collation}) eq "ARRAY") {
			if ($publication->{collation}) {
				foreach my $collation (@{$publication->{collation}}) {
					if ($collation->{lang} eq 'eng') {
						$collationContent = &fix_string ($collation->{content});
						print OUTFILETXT 'Collation [300 ## |b]: ' . $collationContent;
						
					}
				}	
			}	
		}
	
		if ($paginationDescriptionContent && $collationContent) {
			$record->append_fields( MARC::Field->new('300', ' ', ' ' , a => $paginationDescriptionContent, b => $collationContent));
		} elsif ($paginationDescriptionContent) {
			$record->append_fields( MARC::Field->new('300', ' ', ' ' , a => $paginationDescriptionContent));
		} elsif ($collationContent) {
			$record->append_fields( MARC::Field->new('300', ' ', ' ' , b => $collationContent));
		}
	
		
	
		######### 362: Committee Detail and Issue Designation #########
	
		my $committeeDetailContent = 0;
		if ($publication->{committeeDetail}) {
			foreach my $committeeDetail (@{$publication->{committeeDetail}}) {
				if ($committeeDetail->{lang} eq 'eng') {
					$committeeDetailContent = &fix_string ($committeeDetail->{content});
					print OUTFILETXT 'Committee Header [110 2# |a]: ' . $committeeDetailContent;
	
					
				}
			}
			
		}
	
	
		
		my $issueDesignationContent = 0;
		if (ref($publication->{issueDesignation}) eq "HASH") {
		
			if ($publication->{issueDesignation}->{content}) {
				my $issueDesignationContent = &fix_string ($publication->{issueDesignation}->{content});
				print OUTFILETXT 'Issue Designation [362 1# |b]: ' . $issueDesignationContent;
	
				
			}
			
		} elsif (ref($publication->{issueDesignation}) eq "ARRAY") {
			
			if ($publication->{issueDesignation}) {
				foreach my $issueDesignation (@{$publication->{issueDesignation}}) {
					if ($issueDesignation->{lang} eq 'eng') {
						my $issueDesignationContent = &fix_string ($issueDesignation->{content});
						print OUTFILETXT 'Issue Designation [362 1# |b]: ' . $issueDesignationContent;
		
					}
				}	
			}	
		}
		
	
		if ($committeeDetailContent && $issueDesignationContent) {
			$record->append_fields( MARC::Field->new('362', '1', ' ' , a => $committeeDetailContent, b => $issueDesignationContent));
		} elsif ($committeeDetailContent) {
			$record->append_fields( MARC::Field->new('362', '1', ' ', a => $committeeDetailContent));
		} elsif ($issueDesignationContent) {
			$record->append_fields( MARC::Field->new('362', '1', ' ' , b => $issueDesignationContent));
		}
						
	
	
		######### 500: General Note #########
		
		if (ref($publication->{generalNote}) eq "HASH") {
			
			if ($publication->{generalNote}->{content}) {
				my $generalNoteContent = &fix_string ($publication->{generalNote}->{content});
				print OUTFILETXT 'General Note [500 ## |c]: ' . $generalNoteContent;
				$record->append_fields( MARC::Field->new('500', ' ', ' ' , a => $generalNoteContent));
			
			}
			
		} elsif (ref($publication->{generalNote}) eq "ARRAY") {
	
			if ($publication->{generalNote}) {
				foreach my $generalNote (@{$publication->{generalNote}}) {
					if ($generalNote->{lang} eq 'eng') {
						my $generalNoteContent = &fix_string ($generalNote->{content});
						print OUTFILETXT 'General Note [500 ## |a]: ' . $generalNoteContent;
						$record->append_fields( MARC::Field->new('500', ' ', ' ' , a => $generalNoteContent));
					}
				}	
			}
		}
	
		######### 500: Issue Notes #########
		
		if (ref($publication->{issueNotes}) eq "HASH") {
			
			if ($publication->{issueNotes}->{content}) {
				my $issueNotesContent = &fix_string ($publication->{issueNotes}->{content});
				print OUTFILETXT 'Issue Note [500 ## |c]: ' . $issueNotesContent;
				$record->append_fields( MARC::Field->new('500', ' ', ' ' , a => $issueNotesContent));
			
			}
			
		} elsif (ref($publication->{issueNotes}) eq "ARRAY") {
	
			if ($publication->{issueNotes}) {
				foreach my $issueNotes (@{$publication->{issueNotes}}) {
					if ($issueNotes->{lang} eq 'eng') {
						my $issueNotesContent = &fix_string ($issueNotes->{content});
						print OUTFILETXT 'Issue Note [500 ## |a]: ' . $issueNotesContent;
						$record->append_fields( MARC::Field->new('500', ' ', ' ' , a => $issueNotesContent));
					}
				}	
			}
		}
	
	
		
		######### 650: Subjects #########
		
		if (ref($publication->{subject}) eq "HASH") {
			
			if ($publication->{subject}->{content}) {
				my $subjectContent =  &fix_string ($publication->{subject}->{content});
				print OUTFILETXT 'Subject [650 07 |a]: ' . $subjectContent;
				$record->append_fields( MARC::Field->new('650', '0', '7' , a => $subjectContent, b => 'gcpds'));
			
			}
			
		} elsif (ref($publication->{subject}) eq "ARRAY") {
	
			if ($publication->{subject}) {
				foreach my $subject (@{$publication->{subject}}) {
					if ($subject->{lang} eq 'eng') {
						my $subjectContent = &fix_string ($subject->{content});	
						print OUTFILETXT 'Subject [650 07 |a]: ' . $subjectContent;
						$record->append_fields( MARC::Field->new('650', '0', '7' , a => $subjectContent, b => 'gcpds'));
						
					} 
				}	
			}
		}
	
		
		######### URLS #########
		my $urlFoundFlag = 0;
		if (ref($publication->{url}) eq "HASH") {
			
			if ($publication->{url}->{content}) {
				my $urlContent = &fix_string ($publication->{url}->{content});
	
				print OUTFILETXT 'URL [856 40 |z Internet Archive |u]: http://wayback.archive-it.org/3572/*/' . $urlContent;
				
				if (lookup_url($urlContent, &fix_string ($publication->{gocCatalogueNumber}->{content}), $filename)) {
	
					$record->append_fields( MARC::Field->new('856', '4', '0' , u => 'http://wayback.archive-it.org/3572/*/' . $urlContent, z => 'Internet Archive'));
					
					$urlFoundFlag = 1;
					
				}
			
			}
			
		} elsif (ref($publication->{url}) eq "ARRAY") {
			
			if ($publication->{url}) {
				my %urls;
				
				foreach my $url (@{$publication->{url}}) {
					
					my $urlContent = &fix_string ($url->{content});
					
					unless (exists($urls{$urlContent})) {
						
						#save URLS, don't link to same thing twice
						$urls{$urlContent} = 1;
		
						print OUTFILETXT 'URL [856 40 |z Internet Archive |u]: http://wayback.archive-it.org/3572/*/' . $urlContent;
						
						if (lookup_url($urlContent, &fix_string ($publication->{gocCatalogueNumber}->{content}), $filename)) {
		
						$record->append_fields( MARC::Field->new('856', '4', '0' , u => 'http://wayback.archive-it.org/3572/*/' . $urlContent,  z => 'Internet Archive' ));	
							
							$urlFoundFlag = 1;
							
						}
						
					}
	
				}	
			}
		}	
		
		
		
		
		if ($noTitleFlag) {
			print "no title at " . &fix_string ($publication->{gocCatalogueNumber}->{content}) . "\n";
		}
		
		#only save the record if it links to one or more URLs in the collection
		if ($urlFoundFlag) {
			$fileInMemory .= $record->as_usmarc();
			#print OUTFILEMRC $record->as_usmarc();
			print OUTFILETXT "Record created";
			
		} else {
			print OUTFILETXT "Record not created. No matching URL found.";	
		}
			
		print OUTFILETXT "-\n"; 
		
		$counter++;
		
	}
	
	print OUTFILEMRC $fileInMemory;
	
	}

close OUTFILETXT;
close OUTFILEMRC;
close GOCLOG;




#remove newlines if any and encode as utf8
sub fix_string {
	
	my $string = shift;
	$string = encode("utf8", $string);
	$string =~ s/\n//g;
	$string =~ s/\r//g;
	
	return $string;

	
}

#determine the number of characters to skip for sorting titles
sub count_initial_article {
	#articles in English are a, an, d', de, the
	my $string = shift;
	if ($string =~ /^a\s/i) { return '2'; }
	elsif ($string =~ /^an\s/i) { return '3'; }
	elsif ($string =~ /^de\s/i) { return '3'; }
	elsif ($string =~ /^the\s/i) { return '4'; }
	else { return '0'; }
	
}

sub lookup_url {
	# Look up whether or not URL is in the database of IA URLs, and whether we've already generated a record for it.
		
	my $url = $_[0];
	my $gocNumberCurrent = $_[1];
	my $filenameCurrent = $_[2];
	
	#print "hello: $url $gocNumberCurrent $filenameCurrent\n";
	
	my $query = "SELECT seen, filename, goc FROM urls WHERE url = '$url'";
	my $selectQuery  = $dbh->prepare($query) or die "Can't prepare $query: $dbh->errstr\n";
 
	$selectQuery->execute or die "can't execute the query: $selectQuery->errstr\n";
	
	# If not found return 0 (meaning don't create record. Document is not at IA)
	if ($selectQuery->rows == 0) {
		return 0;
	}
	
	# If found and seen is 'n' (meaning we haven't seen it before) change seen to 'y' in the database 
	# and update goc to $gocCatalogueNumberContent and update filename to $filename and return 1 (meaning create record)
	my @found = $selectQuery->fetchrow_array();
	my $seen = $found[0];
	my $filenameFromDB = $found[1];
	my $gocFromDB = $found[2];
		
		#print "hello: $seen $filenameFromDB $gocFromDB\n";
		#exit;
	if ($seen eq 'n') {
		
		$query = "UPDATE urls SET seen = 'y', filename = '$filenameCurrent', goc = '$gocNumberCurrent' WHERE url = '$url'";
		my $updateQuery = $dbh->prepare($query) or die "Can't prepare $query: $dbh->errstr\n";
		$updateQuery->execute or die "can't execute update query: $updateQuery->errstr\n";
		return 1;
		
	# If found and seen is 'y' (meaning we have seen it before) see if the GOC number matches the current record. 
	# If not record the URL and the GOC numbers and filenames in GOCLOG. Either way, return 0 (meaning don't create record)	
	} elsif ($seen eq 'y') {
		
		my $filenameFromDB = $found[1];
		my $gocFromDB = $found[2];
		
		if ($gocNumberCurrent ne $gocFromDB) {
			print GOCLOG "$url\t$gocFromDB\t$filenameFromDB\t$gocNumberCurrent\t$filenameCurrent";
			return 1;
		} else {
			return 0;	
		}
			
	}


}
 

