#!/usr/bin/env perl

use strict;
use warnings;
use JSON;
use Data::Dumper;

our $uri = 'https://api.github.com';
our $api_header = 'Accept: application/vnd.github.v3+json';
our $auth_header = "Authorization: token $ENV{'GITHUB_TOKEN'}";

print "Environment: " . Dumper(%ENV) . "\n";
my $event_name=$ENV{'GITHUB_EVENT_NAME'};
my $event_data=decode_json(`jq --raw-output . "$ENV{'GITHUB_EVENT_PATH'}"`);

sub get_pull {
	my $body=decode_json(`curl -sSL -H "$auth_header" -H "$api_header" "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/pulls"`);
	print "pull requests: " . Dumper($body);
}

sub assign_milestone {
	my $issue_id = shift;
	my $url = "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/milestones";

	my $milestones = decode_json(`curl -sSL -H "$auth_header" -H "$api_header" "${url}"`);
	print "Milestones: " . Dumper($milestones) . "\n";
}

sub push_event {
	my $event_data = shift;
	my $url = "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/pulls";

	my $num_commits = @{$event_data->{'commits'}};
	print "Number of commits: $num_commits";
	foreach my $commit (@$event_data->{'commits'}) {
		print "id: " . Dumper($commit) . "\n";
	}
}

sub pr_event {
	my $event_data = shift;
	my $url = "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/pulls";
}

sub comment_event {
	my $event_data = shift;
	my $url = "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/pulls";

	if ($event_data->{'action'} eq 'created') {
		print "Action created\n";
		if (not defined $event_data->{'issue'}->{'milestone'}) {
			assign_milestone($event_data->{'issue'}->{'id'});
		}
	if ($event_data->{'action'} eq 'deleted') {
		print "Action deleted\n";
		if (not defined $event_data->{'issue'}->{'milestone'}) {
			assign_milestone($event_data->{'issue'}->{'id'});
		}
	} else {
		print "Action: " . $event_data->{'action'} . "\n";
	}
}

print "Event data: " . Dumper($event_data) . "\n";
if ($event_name eq 'push') {
	push_event($event_data);
} elsif ($event_name eq 'pull_request') {
	pr_event($event_data);
} elsif ($event_name eq 'issue_comment') {
	comment_event($event_data);
} else {
	print "Event $event_name without action.\n";
}
