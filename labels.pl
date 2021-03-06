#!/usr/bin/env perl

use strict;
use warnings;
use JSON;
use Data::Dumper;

our $uri = 'https://api.github.com';
our $api_header = 'Accept: application/vnd.github.v3+json';
our $auth_header = "Authorization: token $ENV{'GITHUB_TOKEN'}";

# Pull requests
sub get_pull_request {
	my $commit = shift;
	my $body = decode_json(`curl -sSL -H "$auth_header" -H "$api_header" "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/pulls"`);

	for my $pr (@$body) {
		my $commits_url = $pr->{'_links'}->{'commits'}->{'href'};
		my $commits = decode_json(`curl -sSL -H "$auth_header" -H "$api_header" "$commits_url"`);
		for my $c (@$commits) {
			my $sha = $c->{'sha'};
			if (defined $sha && $sha eq $commit) {
				return $pr;
			}
		}
	}

	return;
}

# Milestones
sub has_milestone {
	return defined $ENV{'INPUT_MILESTONE'};
}

sub get_milestone_title {
	return $ENV{'INPUT_MILESTONE'};
}

sub has_milestone_assigned {
	my $pr = shift;

	return defined $pr && defined $pr->{'milestone'};
}

sub get_milestone {
	if (has_milestone()) {
		my $milestone_title = get_milestone_title();
		my $url = "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/milestones";
		my $milestones = decode_json(`curl -sSL -H "$auth_header" -H "$api_header" "${url}"`);
		foreach my $milestone (@$milestones) {
			if ($milestone->{'title'} eq $milestone_title) {
				return $milestone;
			}
		}
	}

	return;
}

sub assign_milestone {
	my $pr = shift;

	if (defined $pr and $pr->{'state'} eq 'open') {
		# If we have enabled the clean_milestone variable we clean the previous
		# milestone assigned to the PR.
		if (defined $ENV{'INPUT_CLEAN_MILESTONE'} &&
			$ENV{'INPUT_CLEAN_MILESTONE'} != 0) {
			clean_milestone($pr);
		}

		my $issue_url = $pr->{'issue_url'};
		my $milestone = get_milestone();
		if (defined $milestone && !has_milestone_assigned($pr)) {
			my $res = decode_json(`curl -sSL -X PATCH -H "$auth_header" -H "$api_header" -d '{"milestone": $milestone->{"number"}}' "$issue_url"`);
			print "Milestone set result: " . Dumper($res) . "\n"
				if defined $res->{'errors'};
		}
	}
}

sub clean_milestone {
	my $pr = shift;
	if (defined $pr and $pr->{'state'} eq 'open') {
		my $issue_url = $pr->{'issue_url'};
		if (has_milestone_assigned($pr)) {
			my $res = decode_json(`curl -sSL -X PATCH -H "$auth_header" -H "$api_header" -d '{"milestone": null}' "$issue_url"`);
			print "Milestone set result: " . Dumper($res) . "\n"
				if defined $res->{'errors'};
		}
	}
}

# Labels
sub add_label {
	my $label = shift;
	# my $res = decode_json(`curl -sSL -X PATCH -H "$auth_header" -H "$api_header" -d '{"labels": []}' "$issue_url"`);
}

sub delete_label {
	my $label = shift;
}

# Events
sub push_event {
	my $event_data = shift;
	my $url = "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/pulls";

	# Set the milestone.
	if (has_milestone()) {
		my $defaultCommit = $event_data->{'commits'}[0];
		my $pr = get_pull_request($defaultCommit->{'id'});

		assign_milestone($pr);

		# print "Pull request: " . Dumper($pr) . "\n";
	}

	# my $num_commits = @{$event_data->{'commits'}};
	# print "Number of commits: $num_commits\n";
	# foreach my $commit (@{$event_data->{'commits'}}) {
	#	print "Commit info: " . Dumper($commit) . "\n";
	# }
}

sub pr_event {
	my $event_data = shift;
	my $url = "${uri}/repos/$ENV{'GITHUB_REPOSITORY'}/pulls";

	if (has_milestone()) {
		assign_milestone($event_data->{'pull_request'});
	}

	exit(-1);
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
