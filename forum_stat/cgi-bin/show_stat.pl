#!/usr/bin/perl -w
#
#
use strict;
use lib qw(/home/andozer/Work/forum_stats/trunc/lib);
use DBFunc;
use CollectData;
use CGI qw/:standard/;
use Data::Dumper;

my $dbh = DBFunc::DBConnect();

my %users = %{CollectData::GetUserInfo($dbh)};
my %groups = %{CollectData::GetGroupInfo($dbh, \%users)};

my $p = new CGI;
print 	$p->header(-charset => "UTF-8"),
	$p->start_html(	-title => "Forum stats", 
			-charset => "UTF-8",
			-head => meta({-charset => "UTF-8"})),
	$p->h2("Активность пользователей");

my ($ac, $inac, $p_ac, $p_inac) = (0, 0, 0, 0);
foreach my $uid (sort keys %users)
{
	if ($users{$uid}{'user_posts'})
	{
		++$ac; 
	} else {
		++$inac;
	}
}

my $sum = $ac + $inac;
$p_ac   = $sum ? sprintf("%.1f", $ac*100/$sum) : 0;
$p_inac = $sum ? sprintf("%.1f", $inac*100/$sum) : 0;

my %ac_gr;
my %inac_gr;

foreach my $g (sort keys %groups)
{
	foreach my $m (keys %{$groups{$g}{'members_id'}})
	{
		if ($groups{$g}{'members_id'}{$m}{'user_posts'}) 
		{ 
			$ac_gr{$g}++; 
		} else {
			$inac_gr{$g}++; 
		}
	}
}

print <<EOF
<table border=1 align=center>
<tr align=center>
 <th>Группа</th><th>Численность</th><th>% от общего числа</th><th>% в группе</th>
</tr>
<tr align=center bgcolor=#00ff00>
 <td>Активные</td><td>$ac</td><td>$p_ac</td><td>100</td>
</tr>
EOF
;
foreach my $g (sort keys %ac_gr)
{
	my $s = $ac_gr{$g} + $inac_gr{$g};
	my $p_ac  = $s ? sprintf("%.1f", $ac_gr{$g}*100/$s) : 0;
	my $p_ac_kapla  = $sum ? sprintf("%.1f", $ac_gr{$g}*100/$sum) : 0;
	
	print <<EOF
<tr align=center>
 <td>$g</td><td>$ac_gr{$g}</td><td>$p_ac_kapla</td><td>$p_ac</td>
</tr>
EOF
	;
}

print <<EOF
<tr align=center bgcolor=red>
 <td>Неактивные</td><td>$inac</td><td>$p_inac</td><td>100</td>
</tr>
EOF
;
foreach my $g (sort keys %inac_gr)
{
	my $s = $ac_gr{$g} + $inac_gr{$g};
	my $p_inac  = $s ? sprintf("%.1f", $inac_gr{$g}*100/$s) : 0;
	my $p_inac_kapla  = $sum ? sprintf("%.1f", $inac_gr{$g}*100/$sum) : 0;
	
	print <<EOF
<tr align=center>
 <td>$g</td><td>$inac_gr{$g}</td><td>$p_inac_kapla</td><td>$p_inac</td>
</tr>
EOF
	;
}
print "<tr align=center bgcolor=silver><td>Всего</td><td>$sum</td><td>100</td><td>-</td></tr>\n";
print "</table>\n";

print "<h2>Кто заводит людей?</h2>\n";
# top20 писателей по числу сообщений
# top20 писателей по числу тем
#В чьих темах больше всего просмотров, 
#больше всего ответов, 
#больше всего уникальных участников.
my %auth_stat = %{CollectData::GetAuthorsInfo($dbh)};

print <<EOF
<table border=1 align=center>
<tr>
 <th>Пользователь</th><th>Число сообщений</th><th>Число тем</th><th>AVG(Ответов в теме)</th><th>AVG(Просмотров темы)</th>
</tr>
EOF
;
foreach my $uid (keys %auth_stat)
{
	next unless ($users{$uid}{'topic_starter'} >= 60);
	print <<EOF
<tr align=center>
 <td>$users{$uid}{'username_clean'}</td>
 <td>$users{$uid}{'user_posts'}</td>
 <td>$users{$uid}{'topic_starter'}</td>
 <td>$auth_stat{$uid}{'avg_replies'}</td>
 <td>$auth_stat{$uid}{'avg_views'}</td>
</tr>
EOF
	;
}
print "</table>\n";

DBFunc::DBDisconnect($dbh);
print $p->end_html;
