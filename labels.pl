#!/usr/bin/env perl

use strict;
use warnings;
use JSON;
use Data::Dumper;

our $uri = 'https://api.github.com';
our $api_header = 'Accept: application/vnd.github.v3+json';
our $auth_header = "Authorization: token $ENV{'GITHUB_TOKEN'}";

print "Environment: " . Dumper($ENV) . "\n";
my $event_name=$ENV{'GITHUB_EVENT_NAME'};
my $event_data=decode_json(`jq --raw-output . "$ENV{'GITHUB_EVENT_PATH'}"`);

sub get_pull {
	my $body=decode_json(`curl -sSL -H "$auth_header" -H "$api_header" "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/pulls"`);
	print "pull requests: " . Dumper($body);
}

sub push_event {
	my $event_data = shift;
	my $url = "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/pulls";

	my $num_commits = length(@{$event_data->{'commits'}});
	print "Number of commits: $num_commits";
	foreach my $commit (@{$event_data->{'commits'}}) {
		print "id: " . $commit->{'id'} . "\n";
	}

	print "Event data: " . Dumper($event_data) . "\n";
}

if ($event_name eq 'push') {
	push_event($event_data);
} else {
	print "Event $event_name without action.\n";
	print "Event data: " . Dumper($event_data) . "\n";
}
