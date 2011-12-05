package Finders;
use Moose;

has url => (
    is => 'rw',
    isa => 'WWW::Mechanize::Link',
);

has mech => (
    is => 'ro',
    isa => 'WWW::Mechanize',
    lazy_build => 1,
);

has save_as => (
    is => 'rw',
    isa => 'Str',
);

has is_available => (
    is => 'rw',
    isa => 'Int',
);

sub _build_mech {
    my $self = shift;

    my $mech = WWW::Mechanize->new;
    $mech->agent_alias('Linux Mozilla');
    return $mech;
}

sub zeneric {
    my ($self, $mech, $res) = @_;

    my @links = $mech->find_all_links(text_regex => qr/pdf|full[\s-]?text|reprint/i);
    $self->mech->get($links[0]->url_abs()) if @links;
}

sub springer_link {
    my ($self, $mech, $res) = @_;

    my @links = $mech->find_all_links(url_regex => qr/fulltext.pdf$/i);
    $self->mech->get($links[0]) if @links;
}

sub humana_press {
    my ($self, $mech, $res) = @_;

    my @links = $mech->find_all_links(url_regex => qr/task=readnow/i);
    $self->mech->get($links[0]) if @links;
}

sub blackwell_synergy {
    my ($self, $mech, $res) = @_;

    my $uri = $res->base;
    return unless $uri =~ /\/doi\/abs\//i;
    $uri =~ s/abc/pdf/;
    $self->mech->get($uri);
}

sub wiley {
    my ($self, $mech, $res) = @_;

    my @links = $mech->find_all_links(
        text_regex => qr/pdf/i,
        url_regex => qr/pdfstart/i,
    );

    my $r = $self->mech->get($links[0]);
    my @l = $self->mech->find_all_links(
        tag_regex => qr/^frame$/i,
        name_regex => qr/main/i,
        url_regex => qr/mode=pdf/i,
    );

    $self->mech->get($l[0]) if @l;
}

sub science_direct {
    my ($self, $mech, $res) = @_;

    my $uri = $res->base;
    return unless $uri =~ /sciencedirect/i;
    $uri =~ s/abc/pdf/;
    $self->mech->get($uri);
}

sub choose_science_direct {
    my ($self, $mech, $res) = @_;

    # pass;
    undef;
}

sub ingenta_connect {
    my ($self, $mech, $res) = @_;

    my @links = $mech->find_all_links(url_regex => qr/mimetype=.*pdf$/i);
    $self->mech->get($links[0]) if @links;
}

sub cell_press {
    my ($self, $mech, $res) = @_;

    return undef;
    # ruby regex 문법을 모르겠음
    my @links = $mech->find_all_links(url_regex => qr/cell|cancer cell|developmental cell|molecular cell|neuron|structure|immunity|chemistry.+biology|cell metabolism|current biology/i);

    if (@links) {
        my $find_res = $self->mech->get($links[0]);
        return unless $find_res->is_success;

        my ($uid) = $find_res->base =~ m/uid=(.+)/i;
        # WTF..
    }
}

sub jbc {
    my ($self, $mech, $res) = @_;

    my @links = $mech->find_all_links(url_regex => qr/mimetype=.*pdf$/i);
    return unless @links;

    my $find_res = $self->mech->get($links[0]);
    return unless $find_res->is_success;

    @links = $self->mech->find_all_links(
        url_regex => qr/pdf/i,
        text_regex => qr/reprint/i,
    );
    return unless @links;

    $find_res = $self->mech->get($links[0]);
    return unless $find_res->is_success;

    @links = $self->mech->find_all_links(
        tag_regex => qr/frame/i,
        text_regex => qr/reprint/i,
    );
    return unless @links;

    $find_res = $self->mech->get($links[0]);
    return unless $find_res->is_success;

    @links = $self->mech->find_all_links(
        url_regex => qr/.pdf$/i,
    );

    $self->mech->get($links[0]) if @links;
}

sub nature {
    my ($self, $mech, $res) = @_;

    my @links = $mech->find_all_links(
        url_regex => qr/pdf$/i,
        text_regex => qr/Download pdf/i,
    );

    $self->mech->get($links[0]->url_abs) if @links;
}

sub nature_reviews {
    my ($self, $mech, $res) = @_;

    my @links = $mech->find_all_links(
        tag_regex => qr/frame/i,
        name_regex => qr/navbar/i,
    );
    return unless @links;

    my $find_res = $self->mech->get($links[0]);
    return unless $find_res->is_success;

    @links = $self->mech->find_all_links(
        url_regex => qr/pdf$/i,
    );

    $self->mech->get($links[0]) if @links;
}

sub pubmed_central {
    my ($self, $mech, $res) = @_;

    my @links = $mech->find_all_links(
        url_regex => qr/blobtype=pdf/i,
        text_regex => qr/pdf/i,
    );

    $self->mech->get($links[0]) if @links;
}

sub citation_pdf_url {
    # wth..
}

sub direct_pdf_link {
    # wth..
}


__PACKAGE__->meta->make_immutable;

package Pdfetch;
use Moose;
use WWW::Mechanize;

has save_dir => (
    is => 'ro',
    isa => 'Str',
    writer => '_save_dir',
    default => 'pdf',
);

has mech => (
    is => 'ro',
    isa => 'WWW::Mechanize',
    lazy_build => 1,
);

sub _build_mech {
    my $self = shift;

    my $mech = WWW::Mechanize->new;
    $mech->agent_alias('Linux Mozilla');
    return $mech;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;
use Pod::Usage;
use Getopt::Long;
use File::Slurp 'slurp';
use Log::Handler;

my $URI = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&id=%s&retmode=ref&cmd=prlinks&tool=pdfetch";

my %options;
GetOptions(\%options, "--save_dir", "--help");

my $log = Log::Handler->new;
$log->add(
    file => {
        filename => 'pubmed.log',
        maxlevel => 'debug',
        minlevel => 'emergency',
    },
    screen => {
        log_to => 'STDOUT',
        #maxlevel => 'info',
        #minlevel => 'notice',
        maxlevel => 'debug',
        minlevel => 'emergency',
    }
);

run(\%options, @ARGV);

sub run {
    my ($opts, @pmid) = @_;

    pod2usage(0) if $opts->{help};

    my $fetch = Pdfetch->new;
    $fetch->_save_dir($opts->{save_dir}) if $opts->{save_dir};

    for my $id (@pmid) {
        get($fetch, $id);
    }
}

sub get {
    my ($fetch, $pmid) = @_;

    my $success = 0;
    my $save_as = sprintf("%s/%s.pdf", $fetch->save_dir, $pmid);

    if (-e $save_as) {
        $log->info("We already have [$save_as]");
        $success = 1;
    } else {
        my $uri = sprintf $URI, $pmid;
        my $res = $fetch->mech->get($uri);
        return unless $res->is_success;

        if ($fetch->mech->uri->as_string =~ /www\.ncbi\.nlm\.nih\.gov/) {
            $log->info("According to Pubmed no full text exists for $pmid");
            return;
        }

        my $finders = Finders->new;
        for my $method (sort qw/zeneric springer_link humana_press blackwell_synergy wiley science_direct choose_science_direct ingenta_connect cell_press jbc nature nature_reviews pubmed_central citation_pdf_url direct_pdf_link/) {
            $log->debug("Trying $method");
            my $find_res = $finders->$method($fetch->mech, $res);
            next unless $find_res && $find_res->is_success;
            if ($find_res->header('Content-Type') =~ m{^application/pdf$}i) {
                open my $fh, ">", $save_as or die "$save_as open failed: $!\n";
                binmode $fh;
                print $fh $res->content if defined $fh;
                close $fh;
                $log->info("Succesfully downloaded $pmid using $method");
                $success = 1;
                last;
            }
        }
    }

    return $success;
}

__END__

=head1 NAME

pubmed.pl - download pdf by pmid

=head1 SYNOPSIS

    $ pubmed.pl PMID[, PMID, ...]

=head1 DESCRIPTION

=head1 LICENSE

same as Perl.

=head1 AUTHOR

Hyungsuk Hong

=cut
