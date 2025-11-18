package Koha::Plugin::Com::ByWaterSolutions::AuthCheck;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Auth;
use Koha::SearchEngine;
use MARC::Record;

## Here we set our plugin version
our $VERSION = "{VERSION}";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name   => 'Unused Authority Report',
    author => 'Nick Clemens',
    description => 'This plugin searches your system for authorities that have no attached records',
    date_authored   => '2016-02-25',
    date_updated    => '1900-01-01',
    minimum_version => '3.18',
    maximum_version => undef,
    version         => $VERSION,
};

## This is the minimum code required for a plugin's 'new' method
##iMore can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

sub install {
    return 1;
}

sub uninstall {
    return 1;
}

=head3 upgrade

Takes care of upgrading whatever is needed (table structure, new tables, information on those)

=cut

sub upgrade {
    my ( $self, $args ) = @_;

    # upgrade added after 1.5.8
    my $new_version = "1.5.9";

    if (
        Koha::Plugins::Base::_version_compare(
            $self->retrieve_data('__INSTALLED_VERSION__'), $new_version ) == -1
      )
    {
        # remove unused table
        my $table = $self->get_qualified_table_name('mytable');

        if ( $self->_table_exists($table) ) {
            C4::Context->dbh->do(qq{
                DROP TABLE $table;
            });
        }

        $self->store_data( { '__INSTALLED_VERSION__' => $new_version } );
    }
	return 1;
}

## The existance of a 'report' subroutine means the plugin is capable
## of running a report. This example report can output a list of patrons
## either as HTML or as a CSV file. Technically, you could put all your code
## in the report method, but that would be a really poor way to write code
## for all but the simplest reports
sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('output') ) {
        $self->report_step1();
    }
    else {
       $self->report_step2();
    }
}

## These are helper functions that are specific to this plugin
## You can manage the control flow of your plugin any
## way you wish, but I find this is a good approach
sub report_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'report-step1.tt' });

    print $cgi->header();
    print $template->output();
}

sub report_step2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $dbh = C4::Context->dbh;

    my $output = $cgi->param('output');
    my $lower_lim = $cgi->param('lower_lim');
    my $upper_lim = $cgi->param('upper_lim');
    my $type_lim = $cgi->param('type_lim');
    my $check_lim = $cgi->param('check_lim') || 5_000;
    my $created_date = $cgi->param("created_date");

    my @query_params;
    my $query = "SELECT authid,authtypecode,IF( authtypecode='CORPO_NAME',ExtractValue(marcxml,'//datafield[\@tag=\"110\"]/*'),
                               IF( authtypecode='GENRE/FORM',ExtractValue(marcxml,'//datafield[\@tag=\"155\"]/*'),
                               IF( authtypecode='GEOGR_NAME',ExtractValue(marcxml,'//datafield[\@tag=\"151\"]/*'),
                               IF( authtypecode='MEETI_NAME',ExtractValue(marcxml,'//datafield[\@tag=\"111\"]/*'),
                               IF( authtypecode='PERSO_NAME',ExtractValue(marcxml,'//datafield[\@tag=\"100\"]/*'),
                               IF( authtypecode='TOPIC_TERM',ExtractValue(marcxml,'//datafield[\@tag=\"150\"]/*'),
                               IF( authtypecode='UNIF_TITLE',ExtractValue(marcxml,'//datafield[\@tag=\"130\"]/*'),''))))))) AS main_term,
                               modification_time,
                               ExtractValue(marcxml,'//controlfield[\@tag=\"005\"]') AS marcdate,
                               ExtractValue(marcxml,'//datafield[\@tag=\"035\"]/subfield[\@code=\"a\"]') AS syscontrol,
                               ExtractValue(marcxml,'//datafield[\@tag=\"040\"]/subfield[\@code=\"a\"]') AS origsource
        FROM auth_header";
    if ( $lower_lim * $upper_lim ) {
        $query .= " WHERE authid BETWEEN ? AND ? ";
        push @query_params, ( $lower_lim, $upper_lim );
    } elsif ($lower_lim) {
        $query .= " WHERE authid > ? ";
        push @query_params, $lower_lim;
    } elsif ($upper_lim) {
        $query .= " WHERE authid < ? ";
        push @query_params, $upper_lim;
    }
    if ( $type_lim ne 'All' ) {
        if ( $upper_lim || $lower_lim ) {
            $query .= " AND authtypecode = ? ";
            push @query_params, $type_lim;
        } else {
            $query .= " WHERE authtypecode = ? ";
            push @query_params, $type_lim;
        }
    }
    if ($created_date) {
        if ( $lower_lim || $upper_lim || $type_lim ne 'All' ) {
            $query .= " AND datecreated = ? ";
            push @query_params, $created_date;
        } else {
            $query .= " WHERE datecreated = ? ";
            push @query_params, $created_date;
        }
    }
    $query .= " ORDER BY authtypecode, main_term";
    my $sth = $dbh->prepare($query);
    $sth->execute(@query_params);
    my $i=0;
    my @results;
    while ( my $row = $sth->fetchrow_hashref() ) {
        $i++;
        if($i>$check_lim){last;}
        my $a_query = 'an='.$row->{'authid'};
	my $searcher = Koha::SearchEngine::Search->new( { index => $Koha::SearchEngine::BIBLIOS_INDEX } );
	my ( $errors, $results, $used ) = $searcher->simple_search_compat( $a_query, 0, 10 );
        $used = 0 if defined $errors;
        next if $used > 0;
        push @results, $row;
    }


    my $filename;
    if ( $output eq "csv" ) {
        print $cgi->header( -attachment => 'unusedauthorities.csv' );
        $filename = 'report-step2-csv.tt';
    }
    else {
        print $cgi->header();
        $filename = 'report-step2-html.tt';
    }

    my $template = $self->get_template({ file => $filename });

    $template->param(
        results_loop => \@results,
    );

    print $template->output();
}

=head3 _table_exists (helper)

Method to check if a table exists in Koha.

FIXME: Should be made available to plugins in core

=cut

sub _table_exists {
    my ($self, $table) = @_;
    eval {
        C4::Context->dbh->{PrintError} = 0;
        C4::Context->dbh->{RaiseError} = 1;
        C4::Context->dbh->do(qq{SELECT * FROM $table WHERE 1 = 0 });
    };
    return 1 unless $@;
    return 0;
}

1;
