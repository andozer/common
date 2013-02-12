#!/usr/bin/perl -w
#
use strict;
use Data::Dumper;

my $goods_list = "goods_list";
my $transactions = "transaction_list";

my %t; # key - transaction_idl; value - massive of goods ids;
my %nabor;
my @goods;
my $trans_count = 0;
my $supp_min = 0.5;
my $debug = 0;

open(GOODS,"<$goods_list") or die "Can't open $goods_list : $!\n";
while(<GOODS>)
{
	next unless (/^(\d+)\s+(\S+)\s+(\d+)/);
	my @line = split " ", $_;
	push @goods, $line[0];
}
close(GOODS);

open(TRANS,"<$transactions") or die "Can't open $transactions : $!\n";
while(<TRANS>)
{
	next unless (/^(\d+)\s+(\d+)\s+(\S+)\s+(\d+)/);
	my ($tr_id, $goods_id, $goods_name, $price) = ($1, $2, $3, $4);
	#print "$tr_id, $goods_id, $goods_name, $price\n";
	push @{$t{$tr_id}}, $goods_id;
	$trans_count = ($tr_id+1) if ($tr_id+1 > $trans_count);
}
close(TRANS);

#print join " ", @goods;
#print "\n";
print Dumper(\%t) if $debug;

# Main part
my @candidates;
for (my $i = 0; $i<scalar(@goods); $i++)
{
	push my @temp, $goods[$i];
	@{$candidates[$i]} = (@temp);
}

for (my $k = 1; scalar(@candidates)>0; $k++)
{
	print "Ш аг $k. Набор кандидатов ".scalar(@candidates) . ": ". (Dumper(\@candidates)) ."\n" if $debug;
	# Рассчитать поддержку k-элементных наборов
	my %supp; # Здесь храним значение поддержки для набора (номер набора и значение поддержки)

	# Проинициализируем поддержку всех наборов
	# По дефолту. Для тех товаров, которых вообще нет в списке транзакций
	for (my $i = 1; $i<scalar(@candidates); $i++)
	{
		$supp{$i}{'supp'} = 0;
	}

	# Обработка каждой транзакции
	foreach my $key (sort keys %t) # $key - номер транзакции
	{
		print "Transaction: ". (join " ", @{$t{$key}})."\n" if $debug;
		my $c = 1; # Счётчик номера набора.
		foreach my $elem (@candidates) # Обрабатываем каждый набор по очереди
		{
			print "Набор: ". (join " ", @{$elem}) . "\n" if $debug;
			my $in_basket_count = 0; # Сколько товаров из набора присутствуют в корзине?
			foreach my $good_id (@{$elem}) # Сравниваем каждый товар из набора 
			# и сравниваем с корзиной
			{
				foreach my $goods (@{$t{$key}}) # Берём каждый товар из корзины и сравниваем
				# с текущим товаром из набора
				{
					if ($goods == $good_id)
					{
						$in_basket_count++;
						#print "Товар \"$good_id\" из набора присутствует\n";
						last;
					}
				}
			}
			# Обработали все товары из набора и сравнили с данной странзакцией
			if ($in_basket_count == scalar(@{$elem}))
			{
				$supp{$c}{'supp'}++;
				@{$supp{$c}{'contents'}} = (@{$elem});
				print "Набор ".(join " ", @{$elem})." присутствует в транзакции Supp=$supp{$c}{'supp'}\n" if $debug;

			} else 
			{ 
				print "Набор ".(join " ", @{$elem})." отсутствует $in_basket_count ".scalar(@{$elem})."\n" if $debug; 
			}
			$c++
		}
	}
#	print Dumper (\%supp);
	foreach (sort keys %supp)
	{
		$supp{$_}{'supp'} = $supp{$_}{'supp'} / $trans_count;
		push @{$nabor{$k}}, $supp{$_}{'contents'} if ( $supp{$_}{'supp'} >= $supp_min);
#		printf "%d %.2f\n", $_, $supp{$_}{'supp'};
	}
	print Dumper(\%supp) if $debug;
	#last if ($k>=2);
	# Далее нужно сформировать наборы из двух и более элементов.
	@candidates = "";
	shift @candidates;
	print "Текущие $k - элементные наборы : \n" if $debug;
	print Dumper(\@{$nabor{$k}}) if $debug;
	for (my $i = 0; $i<scalar(@{$nabor{$k}})-1; $i++)
	{
		print "Сравниваем набор ".(join " ", @{${$nabor{$k}}[$i]})." с остальными\n" if $debug;
		for (my $nabor_num = $i+1; $nabor_num < scalar(@{$nabor{$k}}); $nabor_num++)
		{
			print "Сравниваем с ".(join " ", @{${$nabor{$k}}[$nabor_num]})."\n" if $debug;
			for (my $j = 0; $j<=($k-1); $j++)
			{
				if (${${$nabor{$k}}[$i]}[$j] == ${${$nabor{$k}}[$nabor_num]}[$j])
				{
					next;
	
				} elsif ($j == $k-1)
				{
					if (${${$nabor{$k}}[$i]}[$j] < ${${$nabor{$k}}[$nabor_num]}[$j])
					{
						push @{$candidates[scalar(@candidates)]}, (@{${$nabor{$k}}[$i]}, ${${$nabor{$k}}[$nabor_num]}[$j]);
					} else
					{
						push @{$candidates[scalar(@candidates)]}, (@{${$nabor{$k}}[$nabor_num]}, ${${$nabor{$k}}[$i]}[$j]);
					}
					
				}  else { last; }
			}
		}
	}
}
print "==============================\n";
print "Найденные часто встречающиеся наборы:\n";
print Dumper(\%nabor);
