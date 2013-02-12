#!/usr/bin/perl -w
#
package Apriori;

use strict;
use Data::Dumper;
our $debug = 0;

sub ApriorySimple($$$$)
{
	# Gets transaction data, items data(objects), support and confidence values.
	# Returns structure with k-element frequent patterns from $item_ref.
	my ($t_ref, $item_ref, $min_sup, $min_conf) = @_;
	my @candidates;
	my $trans_count = 0;
	my %nabor;

	# On first step we generate 1-element patterns
	for (my $i = 0; $i<scalar(@{$item_ref}); ++$i)
	{
	        push my @temp, $item_ref->[$i];
	        @{$candidates[$i]} = (@temp);
	}

	for (my $k = 1; scalar(@candidates)>0; ++$k)
	{
	        print "Ш аг $k. Набор кандидатов ".scalar(@candidates) . ": ". (Dumper(\@candidates)) ."\n" if $debug;

	        # Count support for k-element patterns
	        my %supp; # key - pattern number; value - support for pattern
	
		# Inicialize pattern value. Set all to zero.
	        for (my $i = 1; $i<scalar(@candidates); ++$i)
	        {
	                $supp{$i}{'supp'} = 0;
	        }	
		
	        # Process each transaction
	        foreach my $key (sort keys %{$t_ref}) # $key - transaction_id
	        {
	                print "Transaction: ". (join " ", @{$t_ref->{$key}})."\n" if $debug;

	                my $c = 1; # Pattern number counter

			# Process all patterns one by one
	                foreach my $elem (@candidates) 
	                {
	                        print "Набор: ". (join " ", @{$elem}) . "\n" if $debug;

				# How much items are present in current transaction?
	                        my $in_basket_count = 0; 

				# Take each item from candidate and look for it in transaction
	                        foreach my $good_id (@{$elem})  
	                        {
					# Take each item from transaction and 
					# compare it with current item from candidate
	                                foreach my $goods (@{$t_ref->{$key}}) 
	                                {
	                                        if ($goods == $good_id)
	                                        {
							# Item from candidate is present in transaction
	                                                $in_basket_count++;
	                                                last;
	                                        }
	                                }
	                        }	
				# Process each item from candidate and compare it with transaction
                        	if ($in_basket_count == scalar(@{$elem}))
                        	{
                        	        $supp{$c}{'supp'}++;
                        	        @{$supp{$c}{'contents'}} = (@{$elem});

					print "Набор ".(join " ", @{$elem}).
					" присутствует в транзакции Supp=$supp{$c}{'supp'}\n" if $debug;
	                        } else {
	                                print "Набор ".(join " ", @{$elem}).
					" отсутствует $in_basket_count ".scalar(@{$elem})."\n" if $debug;
	                        }
	                        $c++
                	}
        	}
	        foreach (sort keys %supp)
	        {
	                #$supp{$_}{'supp'} = $supp{$_}{'supp'} / $trans_count;

	                $supp{$_}{'supp'} /= ($trans_count>0) ? $trans_count : 1;
	                push @{$nabor{$k}}, $supp{$_}{'contents'} if ( $supp{$_}{'supp'} >= $min_sup);
	        }
	        print Dumper(\%supp) if $debug;

		# Now we need to generate 2 or more elements candidates.
	        @candidates = "";
	        shift @candidates;

	        print "Текущие $k - элементные наборы : \n" if $debug;
	        print Dumper(\@{$nabor{$k}}) if $debug;
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
	                                                push @{$candidates[scalar(@candidates)]}, 
								(@{${$nabor{$k}}[$i]}, 
								${${$nabor{$k}}[$nabor_num]}[$j]);
	                                        } else
	                                        {
	                                                push @{$candidates[scalar(@candidates)]}, 
								(@{${$nabor{$k}}[$nabor_num]}, 
								${${$nabor{$k}}[$i]}[$j]);
	                                        }
	
	                                }  else { last; }
	                        }
	                }
	        }
	}
	return \%nabor;
}

1;
