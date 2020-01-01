#!/usr/bin/env perl

use strict;
use warnings;
use JSON;
use Data::Dumper;

our $uri = 'https://api.github.com';
our $api_header = 'Accept: application/vnd.github.v3+json';
our $auth_header = "Authorization: token $ENV{'GITHUB_TOKEN'}";

sub get_pull_request {
	my $commit = shift;
	my $body = decode_json(`curl -sSL -H "$auth_header" -H "$api_header" "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/pulls"`);

	for my $pr (@$body) {
		my $commits_url = $pr->{'_links'}->{'commits'}->{'href'};
		my $commits = decode_json(`curl -sSL -H "$auth_header" -H "$api_header" "$commits_url"`);
		for my $c (@$commits) {
			if ($c->{'id'} == $commit) {
				return $pr;
			}
		}
	}

	return 0;
}

sub add_label {
	my $label = shift;
}

sub delete_label {
	my $label = shift;
}

sub assign_milestone {
	my $pr = shift;
	my $milestone = shift;
	my $url = "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/milestones";

	my $milestones = decode_json(`curl -sSL -H "$auth_header" -H "$api_header" "${url}"`);
	print "Milestones: " . Dumper($milestones) . "\n";
}

sub push_event {
	# /repos/:owner/:repo/pulls/:pull_number/commits
	my $event_data = shift;
	my $url = "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/pulls";

	my $num_commits = @{$event_data->{'commits'}};
	print "Number of commits: $num_commits\n";
	foreach my $commit (@{$event_data->{'commits'}}) {
		print "Commit info: " . Dumper($commit) . "\n";
		my $curl = $commit->{'url'};

		my $pr = get_pull_request($commit->{'id'});
		print "Pull request: " . Dumper($pr) . "\n";

		if ($pr->{'state'} != 'open') {
			return;
		}

		assign_milestone($pr->{'number'}, 'Milestone 1')
			unless defined $pr->{'milestone'};

		print "Checking commit data at $curl\n";
		my $c = `curl -sSL -H "$auth_header" -H "$api_header" "$curl"`;
		print "Commit response: " . Dumper($c) . "\n";
		my $c_json = decode_json($c);
		print "Commit data: " . Dumper($c_json) . "\n";
	}
}

sub pr_event {
	my $event_data = shift;
	my $url = "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/pulls";
}

sub comment_event {
	my $event_data = shift;
	my $url = "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/pulls";

	my $prs = decode_json(`curl -sSL -H "$auth_header" -H "$api_header" "${url}"`);
	print "Pull Requests: " . Dumper($prs) . "\n";

	if ($event_data->{'action'} eq 'created') {
		print "Action created\n";
		if (not defined $event_data->{'issue'}->{'milestone'}) {
			assign_milestone($event_data->{'issue'}->{'id'});
		}
	} elsif ($event_data->{'action'} eq 'deleted') {
		print "Action deleted\n";
		if (not defined $event_data->{'issue'}->{'milestone'}) {
			assign_milestone($event_data->{'issue'}->{'id'});
		}
	} else {
		print "Action: " . $event_data->{'action'} . "\n";
	}
}

print "Environment: " . Dumper(%ENV) . "\n";
my $event_name=$ENV{'GITHUB_EVENT_NAME'};
my $event_data=decode_json(`jq --raw-output . "$ENV{'GITHUB_EVENT_PATH'}"`);
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
