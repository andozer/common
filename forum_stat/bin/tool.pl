#!/usr/bin/perl -w
#
#
use strict;
use lib qw(/home/andozer/Work/forum_stats/trunc/lib);
use DBFunc;
use CollectData;
use Apriori;
use Data::Dumper;

sub AprioriTest($);
sub GetTime($);
sub GenerateHTML($);

my $dbh = DBFunc::DBConnect();

#DBFunc::DropCacheTables($dbh, undef);
#DBFunc::CreateCacheTables($dbh, undef);
#DBFunc::TruncateCacheTables($dbh, undef);

#DBFunc::DropCacheTables($dbh, undef);
#DBFunc::CreateCacheTables($dbh, undef);
#DBFunc::TruncateCacheTables($dbh, ('user_stat'));

#CollectData::UpdateTopicStat($dbh, undef);

#AprioriTest($dbh);
GenerateHTML($dbh);

DBFunc::DBDisconnect($dbh);

sub GenerateHTML($)
{
	my $dbh = shift;
	
	my $q = "SELECT topic_id,topic_title, topic_replies, author_posts, username_clean, forum_name ".
		"FROM bb_users as u INNER JOIN bb_topics as a ON a.topic_poster = u.user_id ".
		"INNER JOIN topic_stat as b USING ( topic_id ) ".
		"INNER JOIN bb_forums as f USING ( forum_id ) ".
		"WHERE author_posts >= 10 and topic_replies >= 40 ".
		"ORDER BY `b` . `author_posts` DESC;";

	my $sth = $dbh->prepare($q);
	$sth->execute;
	print '<html><head><title>lala</title>
<meta charset="UTF-8" />
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
</head>
<body charset="UTF-8">';
	print "<h3>1. Какие темы поддерживаются их авторами наиболее активно и что это за авторы?</h3>\n";
	print '<table border=1>
<tr><th>Название темы</th><th>Ответов</th><th>Постов автора</th><th>Имя автора</th><th>Форум</th></tr>
';
#<th>Название темы</th>Ответов</td><td>Постов автора</td><td>Имя автора</td><td>Форум</td></tr>
	
	while( my $ref = $sth->fetchrow_hashref)
	{
		#last;
		print "<tr>
<td>$ref->{'topic_title'}</td>
<td align=center>$ref->{'topic_replies'}</td>
<td align=center>$ref->{'author_posts'}</td>
<td align=center>$ref->{'username_clean'}</td>
<td align=center>$ref->{'forum_name'}</td>
";
	}
	print "</table>\n\n";

	$q = "SELECT COUNT( topic_title ) 'POPULAR TOPICS' , forum_name ".
		"FROM bb_topics as a INNER JOIN topic_stat as b USING ( topic_id ) ".
		"INNER JOIN bb_forums as f USING ( forum_id ) ".
		"WHERE author_posts >= 10 AND topic_replies >= 40 ".
		"GROUP BY forum_name ORDER BY `POPULAR TOPICS` DESC;";

	$sth = $dbh->prepare($q);
	$sth->execute;

	print "<h3>2. В каких форумах расположены темы, наиболее активно поддерживаемые их авторами?</h3>\n";
	print '<table border=1>
<tr><th>Форум</th><th>Число попаданий</th></tr>
';
	while( my $ref = $sth->fetchrow_hashref)
	{
		print "<tr>
<td align=center>$ref->{'forum_name'}</td>
<td align=center>$ref->{'POPULAR TOPICS'}</td>
";
	}
	print "</table>\n\n";

	$q = "select count( author_posts ) 'AUTHOR TOPICS' , username_clean from bb_users as u INNER JOIN bb_topics as a ON a.topic_poster = u.user_id INNER JOIN topic_stat as b USING ( topic_id ) where author_posts >= 10 and topic_replies >= 40 GROUP BY u.username_clean DESC ORDER BY `AUTHOR TOPICS` DESC";

	$sth = $dbh->prepare($q);
        $sth->execute;

        print "<h3>3. Кто создаёт такие темы, которые сам активно поддерживает?</h3>\n";
        print '<table border=1>
<tr><th>Форум</th><th>Число попаданий</th></tr>
';
        while( my $ref = $sth->fetchrow_hashref)
        {
                print "<tr>
<td align=center>$ref->{'username_clean'}</td>
<td align=center>$ref->{'AUTHOR TOPICS'}</td>
";
        }
        print "</table>\n\n";

	$q = "select u.username_clean `User Name`,user_posts `USER POSTS`, count(topic_id) `USER TOPICS`, sum(topic_replies) `SUM REPLIES`,sum(topic_views) `SUM VIEWS` from bb_topics t inner join bb_users u on t.topic_poster = u.user_id GROUP BY `User Name` ORDER BY `SUM REPLIES` DESC, `SUM VIEWS` DESC; ";

	$sth = $dbh->prepare($q);
        $sth->execute;

        print "<h3>4. Чьи темы чаще всего комментируют и просматривают?</h3>\n";
        print '<table border=1>
<tr><th>Автор</th><th>Число сообщений</th><th>Создал тем</th><th>Сумма ответов в темах автора</th><th>Сумма просмотров тем автора</th></tr>
';
        while( my $ref = $sth->fetchrow_hashref)
        {
                print "<tr>
<td align=center>$ref->{'User Name'}</td>
<td align=center>$ref->{'USER POSTS'}</td>
<td align=center>$ref->{'USER TOPICS'}</td>
<td align=center>$ref->{'SUM REPLIES'}</td>
<td align=center>$ref->{'SUM VIEWS'}</td>
";
        }
        print "</table>\n\n";


	$q = "SELECT topic_title,uniq_members,username_clean FROM topic_stat INNER JOIN bb_topics USING (topic_id) INNER JOIN bb_users ON topic_poster = user_id WHERE uniq_members>=10 ORDER BY uniq_members DESC;";

	$sth = $dbh->prepare($q);
        $sth->execute;

        print "<h3>5. В каких темах наибольшее число участников?</h3>\n";
        print '<table border=1>
<tr><th>Название темы</th><th>Число уникальных участников</th><th>Автор</th></tr>
';
        while( my $ref = $sth->fetchrow_hashref)
        {
                print "<tr>
<td>$ref->{'topic_title'}</td>
<td align=center>$ref->{'uniq_members'}</td>
<td align=center>$ref->{'username_clean'}</td>
";
        }
        print "</table>\n\n";

	
	$q = "SELECT count(topic_title) TOPICS ,username_clean FROM topic_stat INNER JOIN bb_topics USING (topic_id) INNER JOIN bb_users ON topic_poster = user_id WHERE uniq_members>=10 GROUP BY username_clean ORDER BY TOPICS DESC;";
	
	$sth = $dbh->prepare($q);
        $sth->execute;

        print "<h3>6. В чьих темах разворачиваются бурные дискуссии?</h3>\n";
        print '<table border=1>
<tr><th>Автор</th><th>Число популярных тем</th></tr>
';
        while( my $ref = $sth->fetchrow_hashref)
        {
                print "<tr>
<td align=center>$ref->{'username_clean'}</td>
<td align=center>$ref->{'TOPICS'}</td>
";
        }
        print "</table>\n\n";




	print"</body>\n</html>";

}

sub AprioriTest($)
{
	# Give option - what forum to choose (forum_id)
	# Give option - what post time interval?
	# Choose approrpiate topic_id and user_id (posts). User_id must be uniq.
	my $dbh = shift;

	my $q = "SELECT forum_name,forum_id,forum_topics,forum_posts FROM bb_forums WHERE parent_id != 0";
	my %t;
	my @cols = ('forum_name','forum_id','forum_topics','forum_posts');

	DBFunc::SelectHashRow($dbh, \%t, \@cols, $q);
	#print Dumper \%t;
#          'ЖЕЛЕЗО' => {
#                    'forum_name' => 'ЖЕЛЕЗО',
#                    'forum_posts' => '1007',
#                    'forum_topics' => '108',
#                    'forum_id' => '67'
#                  },
	printf "%-9s %-9s %-9s %-60s\n\n", "ID", "TOPICS", "POSTS", "NAME";
	foreach my $n (sort keys %t)
	{
		printf "%-9d %-9d %-9d %-60s\n", 
			$t{$n}{'forum_id'},  
			$t{$n}{'forum_topics'}, 
			$t{$n}{'forum_posts'},
			$n;
	}
	print "\nEnter space delimited IDs to select.\n";
	my $fids = "";
	until ($fids =~ /^\s*\d+[\d\s]*$/o)
	{
		print "> ";
	 	chomp($fids = <STDIN>);
	}
	$fids =~ s/^\s*//g;
	$fids =~ s/\s*$//g;
	my @f_ids = split(/\s+/o, $fids);

	# Give option - what post time interval?
	#my ($sd, $ed) = (0, 0);
	my ($sd, $ed) = ("2008-09-01 00:00:00", "2008-10-20 12:12:12");
	print "Enter min post time (YYYY-MM-DD hh:mm:ss)\n";
	until ($sd  =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/o)
	{
		print "> ";
		chomp($sd = <STDIN>);
	}
	print "Enter max post time (YYYY-MM-DD hh:mm:ss)\n";
	until ($ed  =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/o)
	{
		print "> ";
		chomp($ed = <STDIN>);
	}
	my $st = GetTime($sd);
	if ($st<0) { die "Invalid min post time entered\n"; }

	my $et = GetTime($ed);
	if ($et<0) { die "Invalid max post time entered\n"; }

	if ($st >= $et) { die "max time is less than min time\n"; }

	# NOW WE NEED TO GET topic_id and uniq user_id
	$q = "SELECT post_id,poster_id,topic_id from bb_posts WHERE forum_id IN (".
		join(",", @f_ids).") AND ".
		"post_time >= $st AND post_time <= $et";

	@cols = ('post_id','poster_id','topic_id');
	%t = ();
	DBFunc::SelectHashRow($dbh, \%t, \@cols, $q);
#	print Dumper \%t;
#          '55559' => {
#                       'topic_id' => '5300',
#                       'post_id' => '55559',
#                       'poster_id' => '392'
#                     },
#
	my @users;
	my %users;
	my %topics;
	foreach my $post_id (keys %t)
	{
		my $u_id = $t{$post_id}{'poster_id'};
		my $t_id = $t{$post_id}{'topic_id'};

		$users{$u_id} = 0;
		push(@{$topics{$t_id}}, $u_id);
	}
	@users = keys(%users);

	# Exclude poster_id duplicates in each topic
	foreach my $tid (keys %topics)
	{
		my %m;
		foreach my $mem (@{$topics{$tid}})
		{
			$m{$mem} = 0;
		}
		@{$topics{$tid}} = sort keys(%m);
	}
	#print Dumper \%topics, \@users;
	#return 0;
	
	#my $t_ref = CollectData::GetTransactions($dbh, undef);
	#print Dumper \@users;
	print "Starting Apriori algoritm on ".scalar(@users)." users ".
		"and ".scalar(keys %topics)." topics\n";
	print "Press Enter to continue ";
	<STDIN>;
	my $pat_ref = Apriori::ApriorySimple(\%topics, \@users, 1, 0);
	#print Dumper $pat_ref;
	foreach my $k (sort keys %$pat_ref)
	{
		print "$k-element rule. ".scalar(@{$pat_ref->{$k}})." rules\n";
	}
}

sub GetTime($)
{
	use Time::Local;

	my $dt = shift;
	unless ($dt =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/o) 
	{
		return -1;
	}
	my ($y, $mo, $d, $h, $mi, $s) = ($1, $2, $3, $4, $5, $6);
	--$mo;
	my $time = timelocal($s,$mi,$h,$d,$mo,$y);
	return $time;
}
