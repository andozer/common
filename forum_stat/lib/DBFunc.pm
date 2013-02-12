#!/usr/bin/perl -w
#
package DBFunc;

use strict;
use DBI::DBD;

sub DBConnect()
{
        my $db = "forum";
        my $host = "localhost";
        my $port = 3306;
        my $user = "root";
        my $pass = "";
        my $data_source = "dbi:mysql:database=$db;host=$host;port=$port";

        my $dbh = DBI->connect($data_source, $user, $pass) or die "Can't connect to database : $!\n";
	$dbh->do("set character set utf8");
	#$dbh->do("set names utf8");

        return $dbh;
}

sub DBDisconnect($)
{
	my $dbh = shift;
	return $dbh->disconnect;
}

sub QuerySingleRow($$)
{
        my ($dbh, $query) = @_;
	my $row_ref;
	my @row;

        my $sth = $dbh->prepare($query);
        $sth->execute;

        while($row_ref = $sth->fetchrow_arrayref)
        {
		push @row, $row_ref->[0];
        }

        $sth->finish;

        return \@row;
}

sub SelectHashRow($$$$)
{
	my ($dbh, $res, $cols, $query) = @_;
	my $row_ref;
	my $key;
	my $i;

	my $sth = $dbh->prepare($query);
        $sth->execute;

	while ($row_ref = $sth->fetchrow_arrayref)
	{
		$key = $row_ref->[0];
		$i = 0;
		foreach (@$cols)
		{
			$res->{$key}{$_} = $row_ref->[$i];
			++$i;
		}
	}
	
	$sth->finish;
}

sub SelectHashRowArray($$$$)
{
	my ($dbh, $res, $cols, $query) = @_;
	my $row_ref;
	my $key;
	my $i;

	my $sth = $dbh->prepare($query);
        $sth->execute;

	while ($row_ref = $sth->fetchrow_arrayref)
	{
		$key = $row_ref->[0];
		push @{$res->{$key}{'members'}}, $row_ref->[1];
	}
	
	$sth->finish;
}

sub CacheTablesStruct()
{
	my $q1 = "CREATE TABLE IF NOT EXISTS `topic_stat` ( \
			`topic_id` mediumint(8) unsigned not null, \
			`uniq_members` mediumint(8) unsigned, \
			`author_posts` mediumint(8) unsigned, \
			`life_time` int(11) unsigned
			) ENGINE=MyISAM;";

	my $q2 = "CREATE TABLE IF NOT EXISTS `user_stat` ( \
			`user_id` mediumint(8) unsigned not null, \
			`answers_total` mediumint(8) unsigned, \
			`views_total` mediumint(8) unsigned, 
			`been_quoted` mediumint(8) unsigned 
			) ENGINE=MyISAM;";

	my $q3 = "CREATE TABLE IF NOT EXISTS `post_stat` ( \
			`post_id` mediumint(8) unsigned not null, \
			`words_total` mediumint(8) unsigned, \
			`words_uniq` mediumint(8) unsigned, \
			`post_length` mediumint(8) unsigned, \
			`spelling_mistakes` mediumint(8) unsigned, \
			`quotes_count` mediumint(8) unsigned, \
			`url_count` mediumint(8) unsigned \
			) ENGINE=MyISAM;";

	my %query_struct;	# key - table name; value - methods (SQL contructions for create, drop, truncate, etc)

	$query_struct{'CREATE'}{'topic_stat'} = $q1;
	$query_struct{'CREATE'}{'user_stat'} = $q2;
	$query_struct{'CREATE'}{'post_stat'} = $q3;
	$query_struct{'DROP'} = "DROP TABLE IF EXISTS";
	$query_struct{'TRUNCATE'} = "TRUNCATE TABLE";

	return \%query_struct;
}

sub CreateCacheTables($$)
{
	my ($dbh, @t) = @_;
	my $struct_ref = CacheTablesStruct();

	unless ($t[0]) 
	{
		@t = keys %{$struct_ref->{'CREATE'}};
	}

	foreach my $table (@t)
	{	
		my $query = $struct_ref->{'CREATE'}{$table};
		my $sth = $dbh->prepare($query);
		$sth->execute;
		$sth->finish;
	}
}

sub DropCacheTables($$)
{
	my ($dbh, @t) = @_;
        my $struct_ref = CacheTablesStruct();

	unless ($t[0])
        {
                @t = keys %{$struct_ref->{'CREATE'}};
        }

        foreach my $table (@t)
        {       
                my $query = "$struct_ref->{'DROP'} $table";
                my $sth = $dbh->prepare($query);
                $sth->execute;
                $sth->finish;
        }
}

sub TruncateCacheTables($$)
{
	my ($dbh, @t) = @_;
        my $struct_ref = CacheTablesStruct();

        unless ($t[0])
        {
                @t = keys %{$struct_ref->{'CREATE'}};
        }

        foreach my $table (@t)
        {       
                my $query = "$struct_ref->{'TRUNCATE'} $table";
                my $sth = $dbh->prepare($query);
                $sth->execute;
                $sth->finish;
        }
}

sub InsertData($$)
{
	my ($dbh, $query) = @_;

	my $sth = $dbh->prepare($query);
	$sth->execute;
	$sth->finish;
}

#sub SelectArrayRow($$$)
#{
#	my ($dbh, $res, $query) = @_;
#	my $row_ref;
#	
#	my $sth = $dbh->prepare($query);
#        $sth->execute;
#
#	while ($row_ref = $sth->fetchrow_arrayref)
#	{
#		push @$res, $row_ref->[0];
#	}
#	
#	$sth->finish;
#}

1;
