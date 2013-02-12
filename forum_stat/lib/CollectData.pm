#!/usr/bin/perl -w
#
#
package CollectData;

use strict;
use lib qw(/home/andozer/Work/forum_stats/trunc/lib);
use Data::Dumper;
use DBFunc;

sub GetUserInfo($)
# Collect different statistics per user.
{
	my ($dbh) = @_;
	my %users;	# key - user_id; value - different attrubutes.
	my $min_support_author_activ = 5; # Topic is important if there are more than VAR replies.

	# Get user list. Get forum stats for user	
	my $q = "SELECT user_id,user_posts,username_clean FROM bb_users WHERE user_id NOT IN (SELECT user_id FROM bb_bots)";
	my @cols = ('user_id', 'user_posts', 'username_clean');
	DBFunc::SelectHashRow($dbh, \%users, \@cols, $q);
	#print Dumper \%users;

	# Get topics messages for user.
	foreach my $uid (keys %users)
	{
		next unless($users{$uid}{'user_posts'});
		$q = "SELECT a.forum_id,forum_name,COUNT(post_id) FROM bb_posts a INNER JOIN bb_forums b ON a.forum_id=b.forum_id WHERE poster_id=$uid GROUP BY forum_name";	
		@cols = ('forum_id', 'forum_name', 'posts_count');
		my %f;
		DBFunc::SelectHashRow($dbh, \%f, \@cols, $q);

		# Find forums where user is topic starter
		$q = "SELECT forum_id,COUNT(topic_id) FROM bb_topics WHERE topic_poster=$uid GROUP BY forum_id;";
		@cols = ('forum_id', 'topics_started');
		DBFunc::SelectHashRow($dbh, \%f, \@cols, $q);

		$users{$uid}{'forums'} = \%f;
	}
	#print Dumper \%users;

	# Get topicstart entry for user
	$q = "SELECT topic_poster,COUNT(topic_id) FROM bb_topics GROUP BY topic_poster";
	@cols = ('user_id', 'topic_starter');
	DBFunc::SelectHashRow($dbh, \%users, \@cols, $q);
	#print Dumper \%users;

	# Get topicstarter activity
	foreach my $uid (keys %users)
	{
		next unless($users{$uid}{'user_posts'});
		$q = "SELECT a.topic_id,topic_replies,COUNT(post_id) FROM bb_topics a INNER JOIN bb_posts b ON a.topic_id=b.topic_id  WHERE topic_poster=$uid AND poster_id=$uid GROUP BY topic_id";
		@cols = ('topic_id', 'topic_replies', 'author_replies');
		my %t;
		DBFunc::SelectHashRow($dbh, \%t, \@cols, $q);
		my ($ans, $author_ans) = (0, 0);
		foreach (keys %t)
		{
			next unless($t{$_}{'topic_replies'} >= $min_support_author_activ);
			$ans += $t{$_}{'topic_replies'};
			$author_ans += $t{$_}{'author_replies'};
		}
		$users{$uid}{'topic_starter_activ'} = $ans ? sprintf("%.6f", $author_ans/$ans) : 0;
	}
	#print Dumper \%users;
	return \%users;
}

sub GetGroupInfo($$)
# Get statistics for user groups. Agregate data.
{
	my ($dbh, $users_ref) = @_;
	my %groups;	# key - group name; value - different stats

	# Get group list
	my $q = "SELECT group_name,user_name FROM LDAP_groups";
	my @cols = ('group_name');
	my %buf;
	DBFunc::SelectHashRowArray($dbh, \%buf, \@cols, $q);
	foreach (keys %buf)
	{
		my $k = $_;
		$k =~ s/^\s*(\S+)\s*$/$1/go;
		push @{$groups{$k}{'members'}}, map lc(), @{$buf{$_}{'members'}};
		#print Dumper $groups{$k};
	}
	#print Dumper \%groups;

	# Get members id
	foreach my $g (keys %groups)
	{
		$q = "SELECT user_id from bb_users WHERE username_clean IN ('".join("','",@{$groups{$g}{'members'}})."')";
		my $t = DBFunc::QuerySingleRow($dbh,$q);
		foreach my $uid (@$t)
		{
			$groups{$g}{'members_id'}{$uid} = $users_ref->{$uid};
		}
	}
	#print Dumper \%groups;
	return \%groups;
}

sub GetAuthorsInfo($)
{
	my ($dbh) = @_;
	my ($lim_st, $lim_c) = (0, 250);
	#my ($lim_st, $lim_c) = (0, 20);
	
	my $q = "SELECT topic_poster,AVG(topic_replies),AVG(topic_views) FROM bb_topics GROUP BY topic_poster ORDER BY AVG(topic_replies) DESC ,AVG(topic_views)  LIMIT $lim_st, $lim_c";
	my %buf;
	my @cols = ('user_id', 'avg_replies', 'avg_views');
	DBFunc::SelectHashRow($dbh, \%buf, \@cols, $q);

	return \%buf;
}

#my $dbh = DBFunc::DBConnect();
#
#my %users = %{GetUserInfo($dbh)};
#my %groups = %{GetGroupInfo($dbh, \%users)};
#
#DBFunc::DBDisconnect($dbh);

1;

# E X A M P L E #          '342' => {
# E X A M P L E #                     'username_clean' => 'andrey.grunau',
# E X A M P L E #                     'topic_starter_activ' => '0.275168',
# E X A M P L E #                     'forums' => {
# E X A M P L E #                                   '67' => {
# E X A M P L E #                                             'forum_name' => 'ЖЕЛЕЗО',
# E X A M P L E #                                             'forum_id' => '67',
# E X A M P L E #                                             'posts_count' => '4'
# E X A M P L E #                                           },
# E X A M P L E #                                   '63' => {
# E X A M P L E #                                             'topics_started' => '2',
# E X A M P L E #                                             'forum_name' => 'ПРОФЕССИЯ-ОБЩИЙ',
# E X A M P L E #                                             'forum_id' => '63',
# E X A M P L E #                                             'posts_count' => '21'
# E X A M P L E #                                           },
#################################################################################################
# E X A M P L E #                                   '62' => {
# E X A M P L E #                                             'topics_started' => '4',
# E X A M P L E #                                             'forum_name' => 'АСПИРАНТЫ',
# E X A M P L E #                                             'forum_id' => '62',
# E X A M P L E #                                             'posts_count' => '12'
# E X A M P L E #                                           }
# E X A M P L E #                                 },
# E X A M P L E #                     'topic_starter' => '68',
# E X A M P L E #                     'user_posts' => '582',
# E X A M P L E #                     'user_id' => '342'
# E X A M P L E #                   },
# E X A M P L E # 

sub UpdateTopicStat($$)
{
	# Gets reference to massive of topic_id and count metrics for them.
	# If no topic_id specified, than process all topics.
	my ($dbh, $arr_ref) = @_;

	my $where_clause = ($arr_ref->[0]) ? "WHERE topic_id IN (".join(",", @$arr_ref).") " : "";

	my $q = "SELECT topic_id,COUNT(DISTINCT poster_id) FROM bb_posts $where_clause GROUP BY topic_id";	
	my @cols = ('topic_id', 'uniq_members');
	my %t;
	
	DBFunc::SelectHashRow($dbh, \%t, \@cols, $q);

#	Example
#          '2003' => {
#                      'uniq_members' => '10',
#                      'topic_id' => '2003'
#                    },

	$where_clause = ($arr_ref->[0]) ? "AND t.topic_id IN (".join(",", @$arr_ref).") " : "";

	$q = "SELECT t.topic_id,COUNT(post_id),(topic_last_post_time-topic_time) \
		FROM bb_topics t INNER JOIN bb_posts p \
		ON t.topic_id = p.topic_id \
		WHERE poster_id = topic_poster $where_clause \
		GROUP BY topic_id";

	@cols = ('topic_id', 'author_posts', 'life_time');	
	my %s;

	DBFunc::SelectHashRow($dbh, \%s, \@cols, $q);

#	Example
#          '5505' => {
#                      'topic_id' => '5505',
#                      'life_time' => '2721152',
#                      'author_posts' => '1'
#                    },
	# Incert values into cache table
	foreach my $id (keys %s)
	{
		my $query = "INSERT INTO topic_stat \
			VALUES ($id, $t{$id}{'uniq_members'}, $s{$id}{'author_posts'}, $s{$id}{'life_time'})";

		DBFunc::InsertData($dbh, $query);
	}
}	

sub UpdateUserStat($$)
{
	# Gets reference to array of user_id's. If none specified than take all users;
	my ($dbh, $arr_ref) = @_;

	# Do we really need this routine? Solution is
	# select u.username_clean,u.user_id,sum(topic_replies) repl,sum(topic_views) from bb_topics t inner join bb_users u on t.topic_poster = u.user_id GROUP BY u.user_id ORDER BY repl DESC limit 30;
	
}

# SOME SPACE FOR MORPHOLOGICAL SUROUTINES
#

# GATHER DATA FOR APRIORI ALGORITHM
sub GetTransactions($$)
{
	# Gets reference to array of topic_id's. If none specified than take all topics;
	my ($dbh, $arr_ref) = @_;

	my $where_clause = ($arr_ref->[0]) ? "AND topic_id IN (".join(",", @$arr_ref).") " : "";

	my $q = "SELECT topic_id,poster_id \
		FROM bb_posts \
		as p INNER JOIN bb_topics as t USING(topic_id) \
		WHERE topic_replies>0 AND $where_clause topic_id >= 5700 ORDER BY topic_id";

	my @cols = ('topic_id', 'poster_id');
	my %t;
	
	DBFunc::SelectHashRowArray($dbh, \%t, \@cols, $q);

#	Example
#          '1691' => {
#                      'members' => [
#                                     '105',
#                                     '308',
#                                     '267'
#                                   ]
#                    },

	# transform %t hash to: key - topic_id; value - massive of post id
	foreach my $tid (keys %t)
	{
		my @m = @{$t{$tid}{'members'}};
		$t{$tid} = \@m;
	}
#	Example
#          '2507' => [
#                      '94',
#                      '269',
#                      '257'
#                    ],
	return \%t;
}


