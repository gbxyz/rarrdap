#!/usr/bin/perl
# Copyright (c) 2018-2023 CentralNic Ltd and contributors. All rights reserved.
# This program is free software; you can redistribute it and/or modify it under
# the same terms as Perl itself.
use Cwd;
use Data::Mirror qw(mirror_file);
use DateTime;
use Getopt::Long;
use IO::File;
use JSON;
use open qw(:utf8);
use utf8;
use strict;

my $VERSION = '0.1';

my $help;
GetOptions('help' => \$help);

pod2usage() if ($help);

my $dir = $ARGV[0] || getcwd();

if (!-e $dir || !-d $dir) {
	printf(STDERR "Error: %s doesn't exist, please create it first\n");
	exit(1);
}

my $json = JSON->new->pretty->canonical;

my $all = {
  'rdapConformance' => [ 'rdap_level_0' ],
  'entitySearchResults' => [],
};

my $file = mirror_file('https://www.icann.org/en/accredited-registrars', 3600 * 6);

my $doc = XML::LibXML->load_html(
    'location'  => $file,
    'recover'   => 2,
    'huge'      => 1,
    'encoding'  => 'UTF-8',
);

my $data = (grep { 'serverApp-state' eq $_->getAttribute('id') && 'application/json' eq $_->getAttribute('type') } $doc->getElementsByTagName('script'))[0]->childNodes->item(0)->data;
$data =~ s/\&q;/"/g;

my $object = $json->decode($data);

my $rars = $object->{'accredited-registrars-{"languageTag":"en","siteLanguageTag":"en","slug":"accredited-registrars"}'}->{'data'}->{'accreditedRegistrarsOperations'}->{'registrars'};

foreach my $rar (sort { $a->{'ianaNumber'} <=> $b->{'ianaNumber'} } @{$rars}) {
    my $id = $rar->{'ianaNumber'};

	my $data = {
		'objectClassName' => 'entity',
		'handle' => sprintf('%s-iana', $id),
		'publicIds' => [ { 'type' => 'IANA Registrar ID', 'identifier' => int($id) }],
		'rdapConformance' => [ 'rdap_level_0' ],
		'status' => [ 'active' ],
		'vcardArray' => [ 'vcard', [ [
			'version',
			{},
			'text',
			'4.0',
		] ] ],
	};

	if ($rar->{'publicContact'}->{'name'}) {
		push(@{$data->{'vcardArray'}->[1]}, [ 'fn', {}, 'text', $rar->{'publicContact'}->{'name'} ]);
		push(@{$data->{'vcardArray'}->[1]}, [ 'org', {}, 'text', $rar->{'name'} ]);

	} else {
		push(@{$data->{'vcardArray'}->[1]}, [ 'fn', {}, 'text', $rar->{'name'} ]);

	}

	if ($rar->{'publicContact'}->{'phone'}) {
		$rar->{'publicContact'}->{'phone'} =~ s/^="//g;
		$rar->{'publicContact'}->{'phone'} =~ s/"$//g;
		push(@{$data->{'vcardArray'}->[1]}, [ 'tel', {} , 'text', $rar->{'publicContact'}->{'phone'} ]);
	};

	push(@{$data->{'vcardArray'}->[1]}, [ 'email', {} , 'text', $rar->{'publicContact'}->{'email'} ]) if ($rar->{'publicContact'}->{'email'});
	push(@{$data->{'vcardArray'}->[1]}, [ 'adr', {} , 'text', [ '', '', '', '', '', '', $rar->{'country'} ] ]) if ($rar->{'country'});

	if ($rar->{'url'}) {
		push(@{$data->{'links'}}, {
			'title' => "Registrar's Website",
			'rel' => 'related',
			'href' => $rar->{'url'}
		});
	}

	$data->{'notices'} = [
		{
			'title'	=> 'About This Service',
			'description' => [
				'Please note that this RDAP service is NOT provided by the IANA.',
				'',
				'For more information, please see https://about.rdap.org',
			],
		}
	];

	$data->{'events'} = [ {
		'eventAction' => 'last update of RDAP database',
		'eventDate' => DateTime->now->iso8601,
	} ];

	#
	# add some links
	#
	push(@{$data->{'links'}}, {
		'title'	=> 'About RDAP',
		'rel'	=> 'related',
		'href'	=> 'https://about.rdap.org',
	});

	#
	# write RDAP object to disk
	#
	my $jfile = sprintf('%s/%s.json', $dir, $data->{'handle'});

	my $file = IO::File->new;
	if (!$file->open($jfile, '>:utf8')) {
		printf(STDERR "Cannot write to '%s': %s\n", $jfile, $!);
		exit(1);

	} else {
		$file->print($json->encode($data));
		$file->close;
	}

    $all->{'notices'} = $data->{'notices'} unless (defined($all->{'notices'}));
    delete($data->{'notices'});
    delete($data->{'rdapConformance'});

    push(@{$all->{'entitySearchResults'}}, $data);
}

#
# write RDAP object to disk
#
my $jfile = sprintf('%s/_all.json', $dir);
my $file = IO::File->new;
if (!$file->open($jfile, '>:utf8')) {
	printf(STDERR "Cannot write to '%s': %s\n", $jfile, $!);
	exit(1);

} else {
	$file->print($json->encode($all));
    $file->close;

}

print STDERR "done\n";

__END__

=pod

=head1 NAME

C<rarrdap.pl> - a script to generate a set of RDAP responses for ICANN-accredited
registrars.

=head1 DESCRIPTION

This script scrapes data from the the ICANN website, and generates RDAP
responses for each ICANN-accredited registrar.

The RDAP responses are written to disk in a directory which can then be exposed
through a web server.

An example of an RDAP service which provides access to this data may be found at
L<https://registrars.rdap.org>, for example:

=over

=item * L<https://registrars.rdap.org/entity/1564-iana>

=back

Entity handles have the "-iana" object tag, as per L<https://www.rfc-editor.org/rfc/rfc8521.html>
I<(the -iana object tag as not been registered with IANA)>.

=head1 USAGE

	rarrdap.pl DIRECTORY

C<DIRECTORY> is the location on disk where the files should be written.
C<rarrdap.pl> will write the .json files to this directory.

If C<DIRECTORY> is not provided, the current directory is used.

=head1 COPYRIGHT

Copyright (c) 2018-2023 CentralNic Ltd and contributors. All rights reserved.

=head1 LICENSE

Copyright (c) 2018-2023 CentralNic Ltd and contributors. All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
