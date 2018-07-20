#!/usr/bin/perl
# Copyright (c) 2018 CentralNic Ltd. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.
use Cwd;
use File::Basename qw(dirname basename);
use File::stat;
use IO::File;
use Getopt::Long;
use JSON;
use List::MoreUtils qw(uniq);
use LWP::UserAgent;
use Text::CSV_XS qw(csv);
use constant IANA_LIST => 'https://www.iana.org/assignments/registrar-ids/registrar-ids-1.csv';
use constant INTERNIC_LIST => 'https://www.internic.net/registrars.csv';
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

my $ua = LWP::UserAgent->new('agent' => sprintf('%s/%s', basename(__FILE__, '.pl'), $VERSION));

my $json = JSON->new->pretty;

my $iana_list = join('/', $dir, basename(IANA_LIST));
if (!-e $iana_list || stat($iana_list)->mtime <= time()-86400) {
	print STDERR "Updating registrar list from IANA\n";
	my $response = $ua->mirror(IANA_LIST, $iana_list);

	if ($response->is_error) {
		if (-e $iana_list) {
			warn($response->status_line);

		} else {
			die($response->status_line);

		}

	} else {
		utime(undef, undef, $iana_list);

	}
}

my $iana = {};
foreach my $row (@{csv('in' => $iana_list, 'headers' => 'auto')}) {
	$iana->{$row->{'ID'}} = $row;
}

my $internic_list = join('/', $dir, basename(INTERNIC_LIST));
if (!-e $internic_list || stat($internic_list)->mtime <= time()-86400) {
	print STDERR "Updating registrar list from Internic\n";
	my $response = $ua->mirror(INTERNIC_LIST, $internic_list);

	if ($response->is_error) {
		if (-e $internic_list) {
			warn($response->status_line);

		} else {
			die($response->status_line);

		}

	} else {
		utime(undef, undef, $internic_list);

	}
}

my $internic = {};
foreach my $row (@{csv('in' => $internic_list, 'headers' => 'auto')}) {
	$internic->{$row->{'iana_id'}} = $row;
}

foreach my $id (sort({ $a <=> $b } uniq(keys(%{$iana}), keys(%{$internic})))) {
	next if ('Terminated' eq $iana->{$id}->{'Status'});

	my $object = {
		'iana' => $iana->{$id},
		'internic' => $internic->{$id},
	};

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

	if ($internic->{$id}->{'NAME'}) {
		push(@{$data->{'vcardArray'}->[1]}, [ 'fn', {}, 'text', $internic->{$id}->{'NAME'} ]);
		push(@{$data->{'vcardArray'}->[1]}, [ 'org', {}, 'text', $iana->{$id}->{'Registrar Name'} ]);

	} else {
		push(@{$data->{'vcardArray'}->[1]}, [ 'fn', {}, 'text', $iana->{$id}->{'Registrar Name'} ]);

	}

	if ($internic->{$id}->{'PHONE'}) {
		$internic->{$id}->{'PHONE'} =~ s/^="//g;
		$internic->{$id}->{'PHONE'} =~ s/"$//g;
		push(@{$data->{'vcardArray'}->[1]}, [ 'tel', {} , 'text', $internic->{$id}->{'PHONE'} ]);
	};

	push(@{$data->{'vcardArray'}->[1]}, [ 'email', {} , 'text', $internic->{$id}->{'EMAIL'} ]) if ($internic->{$id}->{'EMAIL'});
	push(@{$data->{'vcardArray'}->[1]}, [ 'addr', {} , 'text', [ $internic->{$id}->{'country_name'} ] ]) if ($internic->{$id}->{'country_name'});

	if ($internic->{$id}->{'URL'}) {
		$internic->{$id}->{'URL'} = 'http://'.$internic->{$id}->{'URL'} if ($internic->{$id}->{'URL'} !~ /^https?:\/\//);
		push(@{$data->{'links'}}, { 'rel' => 'related', 'href' => $internic->{$id}->{'URL'}});
	}

	push(@{$data->{'remarks'}}, {
		'title' => 'RAA Version',
		'description' => [ int($internic->{$id}->{'RAA'}) ]
	}) if ($internic->{$id}->{'RAA'});

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

	#
	# add some links
	#
	$data->{'links'} = [
		{
			'rel'	=> 'related',
			'href'	=> 'https://about.rdap.org',
		}
	];

	#
	# write RDAP object to disk
	#
	my $jfile = sprintf('%s/%d.json', $data->{'handle'}, $id);

	my $file = IO::File->new;
	$file->open($jfile, '>:utf8');
	$file->print($json->encode($data));
	$file->close;
}

print STDERR "done\n";

__END__

=pod

=head1 NAME

C<rarrdap.pl> - a script to generate a set of RDAP responses for ICANN-accredited registrars.

=head1 DESCRIPTION

This script scrapes data from the the IANA registrar ID registry and the Internic site, and
generates RDAP responses for each ICANN-accredited registrar.

The RDAP responses are written to disk in a directory which can then be exposed through a web
server.

An example of an RDAP service which provides access to this data may be found at
L<https://registrars.rdap.org>, for example:

=over

=item * L<https://registrars.rdap.org/entity/1564-iana>

=back

Entity handles have the "-iana" object tag, as per L<https://tools.ietf.org/html/draft-ietf-regext-rdap-object-tag-04>.

=head1 USAGE

	rarrdap.pl DIRECTORY

C<DIRECTORY> is the location on disk where the files should be written. C<rarrdap.pl> will write
its working files to this directory as well as the finished .json files.

If C<DIRECTORY> is not provided, the current directory is used.

=head1 COPYRIGHT

Copyright 2018 CentralNic Ltd. All rights reserved.

=head1 LICENSE

Copyright (c) 2018 CentralNic Ltd. All rights reserved. This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
