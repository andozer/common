#!/usr/bin/perl -w
#
#
use strict;
use DBI::DBD;
use CGI qw/:standard/;
use Data::Dumper;
use Time::Local;

sub DBConnect();
sub ProcessQuery($$);
sub PostCountUser($$$$$);
sub TopicStartCountUser($$$$$);
sub GetUserTopicID($$$$$);
sub TopicStarterActivity($$$$$);
sub TotalUsers($);
sub GetGroupMembers($$);

my $total_users=1;
my $course_activity=1;

my $dbh = DBConnect();

my $p = new CGI;
print 	$p->header(-charset => "UTF-8"),
	$p->start_html(	-title => "Forum stats", 
			-charset => "UTF-8",
			-head => meta({-charset => "UTF-8"})),
	$p->h2("Выборка по характеристикам пользователей");

if ($total_users)
{
	my ($au, $inau) = TotalUsers($dbh);
	my $p_au = ($au+$inau) ? $au*100/($au+$inau) : 0;
	my $p_inau = ($au+$inau) ? $inau*100/($au+$inau) : 0;

	print $p->table({	-border=>1,
				-align=>"center"},
		Tr({-align=>'CENTER',-valign=>'TOP'},
		[
			th(["Пользователи", 	"Число", 	"Процент"]),
			td(["Активные", 	$au, 		sprintf("%.1f", $p_au)]),
			td(["Неактивные", 	$inau, 		sprintf("%.1f", $p_inau)]),
			td(["Всего", 		$au+$inau, 	100]),
		]));
}

# Отчёт в каких разделях форума представлена учебная группа
# 1) Выбрать все группы
# 2) сформировать список пользователей каждой группы
# 3) Запросить число активных/неактивных пользователей группы (число постов > 0) и неактивных.
# 4) Для списка пользователей user_id IN (список или подзапрос) подсчитать число сообщений в каждом разделе форума
# Какие-то разделы можно детализировать

my $gm;	# hash ref on key - god vypuska, value - massive of members (name.surname)
my $q = "SELECT group_name,user_name FROM LDAP_groups ORDER BY group_name";
$gm  = GetGroupMembers($dbh, $q);
print Dumper $gm;
exit;
foreach my $g (sort keys %$gm)
{
	# Поместим в структуру данных информацию об id пользователей
	my $q = "SELECT user_posts FROM bb_users WHERE username_clean in ('".join("','",@{$gm->{$g}{'members'}})."')";
	my $ref = ProcessQuery($dbh, $q);
	# А можно ещё гистограмму рисовать... сколько постов и пользователей с таким числом постов.
	foreach my $i (@$ref)
	{
		if ($i->[0])
		{
			$gm->{$g}{'active'}++;
			$gm->{$g}{'total_posts'} += $i->[0];
		} else {
			$gm->{$g}{'inactive'}++;
		}
	}
}
# В каком разделе форума эти группы более всего активны. Форумы нижнего уровня.
# Куда пишет конкретный человек
#
# SELECT a.forum_id,forum_name,count(post_id),user_id from bb_posts a inner join bb_forums b ON a.forum_id=b.forum_id inner join bb_users c on a.poster_id=c.user_id  where username_clean='denis.korolev' GROUP BY forum_name ORDER BY count(post_id)
# Чтобы подсчитать для группы, нужно прогнать в цикле
#
# SELECT forum_id,count(post_id) from bb_posts where poster_id=342 GROUP BY forum_id ORDER BY count(post_id);
# SELECT forum_name,count(post_id),username_clean from bb_posts a inner join bb_forums b ON a.forum_id=b.forum_id inner join bb_users c on a.poster_id=c.user_id  where username_clean='denis.korolev' GROUP BY forum_name ORDER BY count(post_id);
# SELECT parent_id,count(post_id) from bb_posts a inner join bb_forums b on a.forum_id=b.forum_id where poster_id=342 GROUP BY parent_id;
#print Dumper $gm;
#exit;

# Отчёт - какая группа пользователей вносит основной вклад (по числу сообщений) в тот или иной форум. С детализацией по 
# подфорумам. 40% - первый курс, 20% выпускники, 20% - остальные.

# Course activity
if ($course_activity)
{
	my @ltime = localtime(time());
	my ($month, $year) = ($ltime[4]+1, $ltime[5]+1900);
	if ($month < 9) { --$year; }
	my $i;
	my $f_year = 2002;
}

my $uq = "SELECT username_clean FROM bb_users WHERE user_id NOT IN (SELECT user_id FROM bb_bots) ORDER BY username_clean";
my $userlist_ref = ProcessQuery($dbh, $uq);

#print Dumper $userlist_ref;
my $user_l_ref;
foreach (@$userlist_ref)
{
	push @$user_l_ref, (shift @$_);
}
unshift @$user_l_ref, "";

print 	start_form(-method => "GET"),
	$p->p("Выберите пользователя:"),
	$p->popup_menu(	-name => "obj",
			-values => $user_l_ref),
	submit(	-name => "choose_object",
		-label => "OK"),
	end_form();

# If user is chosen than print statistics for him
if (param('obj'))
{
	print $p->hr;
	print $p->p("Статистика для ".param('obj'));

	my $q_id = "SELECT user_id FROM bb_users WHERE username_clean=\'".param('obj')."\'";
	
	my $id = ProcessQuery($dbh, $q_id)->[0]->[0];
	print $p->p("ID: $id");

	# Post count
	my $posts = PostCountUser($dbh, $id, undef, undef, undef)->[0]->[0];
	print $p->p("Сообщений: $posts");

	# Topic start count
	my $t_start = TopicStartCountUser($dbh, $id, undef, undef, undef)->[0]->[0];
	print $p->p("Создал тем: $t_start");

	# Activity in own topics
	my $author_activity = TopicStarterActivity($dbh, $id, undef, undef, undef);
	print $p->p("Активность пользователя в своих темах: $author_activity");
}

$dbh->disconnect;
print $p->end_html;


 
sub DBConnect()
{
	my $db = "forum";
	my $host = "localhost";
	my $port = 3306;
	my $user = "root";
	my $pass = "";
	my $data_source = "dbi:mysql:database=$db;host=$host;port=$port";
	
	my $dbh = DBI->connect($data_source, $user, $pass) or die "Can't connect to database : $!\n";

	return $dbh;
}


sub TotalUsers($)
{
	my $dbh = shift;

	my $q_active 	= 'SELECT count(*) from bb_users WHERE user_posts>0';
	my $q_inactive 	= 'SELECT count(*) from bb_users WHERE user_posts=0';

	my $au 		= ProcessQuery($dbh, $q_active)->[0]->[0];
	my $inau 	= ProcessQuery($dbh, $q_inactive)->[0]->[0];

	return ($au, $inau);
}

sub ProcessQuery($$)
{
	my ($dbh, $query) = @_;

	my $sth = $dbh->prepare($query);
	$sth->execute;
	my $row_ref = $sth->fetchall_arrayref;
	$sth->finish;

	return $row_ref;
}

sub GetGroupMembers($$)
{
	my ($dbh) = @_;

	my $q1 = "SELECT group_name,user_name FROM LDAP_groups ORDER BY group_name";

	my $sth = $dbh->prepare($q1);
	$sth->execute;
	my $row_ref;
	my %gm;	# key - god vypuska, value - massive of members (name.surname)
	
	while($row_ref = $sth->fetchrow_arrayref)
	{
		my ($g, $m) = @$row_ref;
		$g =~ s/\s+//go;
		$m = lc($m);
		push @{$gm{$g}{'members'}}, $m;
	}
	$sth->finish;

	foreach my $g (keys %gm)
	{
		$q1 = "SELECT user_id FROM bb_users WHERE username_clean in ('".join("','",@{$gm{$g}{'members'}})."')";
		
		$row_ref = ProcessQuery($dbh, $q1);
		foreach (@$row_ref)
		{
			push @{$gm{$g}{'members_id'}}, (shift @$_);
		}
	}

	return \%gm;
}


sub PostCountUser($$$$$)
{
	my ($dbh, $id, $start, $end, $forum) = @_;

	my $q = "SELECT count(*) FROM bb_posts WHERE poster_id=$id";

	if (defined($start)) 	{ $q .= " AND post_time >= $start"; }
	if (defined($end)) 	{ $q .= " AND post_time <= $end";   }

	return ProcessQuery($dbh, $q);
}

sub TopicStartCountUser($$$$$)
{
	my ($dbh, $id, $start, $end, $forum) = @_;

	my $q = "SELECT count(*) FROM bb_topics WHERE topic_poster=$id";

	if (defined($start)) 	{ $q .= " AND post_time >= $start"; }
	if (defined($end)) 	{ $q .= " AND post_time <= $end";   }

	return ProcessQuery($dbh, $q);
}

sub GetUserTopicID($$$$$)
{
#	my ($dbh, $id, $start, $end, $forum) = @_;
#
#	my $q = "SELECT topic_id FROM bb_topics WHERE topic_poster=$id";
#
#	if (defined($start)) 	{ $q .= " AND post_time >= $start"; }
#	if (defined($end)) 	{ $q .= " AND post_time <= $end";   }
#
#	my $topic_refs = ProcessQuery($dbh, $q);
#
#	my @topics;
#	foreach (@$topic_refs)
#	{
#		push @topics, (shift @$_);
#	}
#	return \@topics;
}

sub TopicStarterActivity($$$$$)
{
	my ($dbh, $id, $start, $end, $forum) = @_;

	# Take all topics started by user;
	# Count messages in each topic;
	# For every topic count percent of user's messages
	# Count average, # max, min
	
	my $topics_ref = GetUserTopicID($dbh, $id, $start, $end, $forum);
	#print Dumper $topics_ref;
	my $topic_id;
	my $q = "SELECT topic_id,topic_replies,topic_views from bb_topics WHERE topic_id IN ( SELECT topic_id from bb_topics INNER JOIN bb_users ON topic_poster=user_id WHERE user_id=$id)";
	
	if (defined($start)) 	{ $q .= " AND post_time >= $start"; }
	if (defined($end)) 	{ $q .= " AND post_time <= $end";   }

	my $topic_refs = ProcessQuery($dbh, $q);
	my %topic_stats;	# key - topic_id ; value - hash (key - attribute ; value - value)
	
	my $activity_min_supp = 5; # Take into account topics with $var or more replies. Ignore other.
	my $t_ref;
	# Count percent of user messages in his topics 
	# Count uniq topic participants 
	foreach $t_ref (@$topic_refs)
	{
		next if ($t_ref->[1] < $activity_min_supp);

		$topic_stats{$t_ref->[0]}{'replies'} = $t_ref->[1];
		$q = "SELECT count(*) FROM bb_posts WHERE topic_id=$t_ref->[0] AND poster_id=$id";
		$topic_stats{$t_ref->[0]}{'author_replies'} = ProcessQuery($dbh, $q)->[0]->[0];
		
		$q = "SELECT DISTINCT username_clean FROM bb_posts INNER JOIN bb_users ON poster_id=user_id WHERE topic_id=$t_ref->[0] ORDER BY username_clean";
		my $p_ref = ProcessQuery($dbh, $q);
		foreach (@$p_ref)
		{
			push @{$topic_stats{$t_ref->[0]}{'participants'}}, (shift @$_);
		}
		
	}
	my ($ans, $user_ans) = (0, 0);
	foreach (values %topic_stats)
	{
		$ans += $_->{'replies'};
		$user_ans += $_->{'author_replies'};
	}
	my $user_activity = $ans ? sprintf("%.6f", $user_ans/$ans) : 0;

	return $user_activity;
}
