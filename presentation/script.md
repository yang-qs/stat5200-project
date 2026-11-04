# Speaker script: replication of Abadie, Diamond & Hainmueller (2010)

Target length is 10 minutes, about 1,300 words at a normal speaking pace. Times in brackets are cumulative.

## 1. Title [0:00]

Hi, I'm Qiaoshi Yang. For the replication assignment I reproduced Abadie, Diamond and Hainmueller's 2010 *JASA* paper, the one that introduced synthetic control to most economists through California's Proposition 99.

## 2. The paper and why I chose it [0:15]

The question is simple. California passed a large tobacco control program in 1988. How much did it reduce cigarette sales?

Answering it is harder than it sounds, because there is exactly one treated state. And California doesn't look like the rest of the country before 1988, so comparing it with the US average, which is a plain difference-in-differences, isn't credible.

The paper's answer is the synthetic control method. Instead of picking a comparison state by hand, you let the data build one as a weighted average of untreated states, and you do inference by running the same procedure on every state that wasn't treated.

I picked this paper because of my final project. Massachusetts passed an almost identical program four years later, and I want to know whether the California result carries over. Replicating California first means I can apply the same code and data to Massachusetts and know that any difference comes from the policy, not from my implementation.

## 3. Setting: Proposition 99 [1:15]

Proposition 99 passed in November 1988 and took effect in January 1989. It raised the cigarette tax by 25 cents a pack and earmarked the revenue for health and anti-smoking education: media campaigns, school programs, and local clean-air ordinances. In its first years it funded more than 100 million dollars a year of anti-tobacco projects.

The figure shows why you need a careful comparison. California, the solid line, was already falling faster than the average donor state well before 1989. A naive before-and-after comparison would credit that existing decline to the policy.

## 4. Method: synthetic control [2:00]

Here's the setup. State 1 is California, and there are 38 donor states. The effect in each year after 1988 is the difference between California's actual sales and what sales would have been without the program. We estimate that counterfactual as a weighted average of donors' sales.

The weights are non-negative and sum to one, and they're chosen so that the weighted donors match California on pre-1989 predictors. The matrix V weights those predictors, and it is itself chosen to minimise the pre-period prediction error for sales.

The justification is a factor model. If you can match California's sales over a long pre-period, you are also matching the unobserved factors that drive sales. And because the weights are a convex combination, there is no extrapolation outside the donors' range.

For inference, you pretend each donor state was treated, rerun the method, and ask where California falls in the distribution of post- to pre-treatment fit ratios.

## 5. Data and design choices [3:00]

The outcome is per-capita cigarette sales in packs from 1970 to 2000, computed from state tax revenue. The predictors are log income, retail price and the share of people aged 15 to 24, averaged over 1980 to 1988, beer consumption averaged over 1984 to 1988, and sales in three years: 1975, 1980 and 1988.

The donor pool is a design choice that matters. The authors drop four states that started their own large tobacco programs, seven states that raised cigarette taxes by 50 cents or more, and DC. That leaves 38 states. The sample stops in 2000 because after the 1998 Master Settlement Agreement, many states started anti-tobacco measures and stop being valid controls.

## 6. Paper's results [3:45]

Synthetic California is mostly Utah, Nevada, Montana and Colorado, with a little Connecticut. The pre-1989 fit is tight. By 2000, California's sales were about 26 packs per capita below synthetic California, and over the whole 1989 to 2000 period the reduction averages almost 20 packs, roughly 25 percent.

California's post- to pre-period fit ratio is the largest of all 39 states, so the permutation p-value is 1 over 39, or 0.026.

## 7. My replication [4:20]

My goal was to rebuild the data from public sources rather than download the authors' file. Sales and prices come from the CDC's release of *The Tax Burden on Tobacco*, income from the BEA, the age share from SEER population data, and beer from the NIAAA. The estimator is the same R package, `Synth`, that the authors distribute.

I kept the same donor pool, predictors and averaging windows. Everything runs from one script, `run_all.R`, which downloads the raw data and regenerates every table and figure, and it's all on GitHub.

## 8. Predictor balance [5:00]

This table puts the paper's Table 1 next to mine. The lagged sales values match the paper to the decimal, so the outcome series is the same. The covariates don't match in levels, and that's expected: I use nominal personal income where the paper uses 1997 dollars, beer per resident aged 14 and over rather than per capita, and a revised price series. Since every state's predictor uses the same definition, what matters for the weights is the relative position of states, and that is much less sensitive.

## 9. Weights and paths [5:45]

Four of the paper's five donors come back with positive weight, and Utah, Nevada and Connecticut have almost the same weights. Montana drops out and Colorado's weight roughly doubles.

On the right, the replicated paths look like the paper's Figure 2. Synthetic California tracks the real one closely until 1988, then the two lines separate and the gap keeps growing.

## 10. Inference [6:20]

On the left are the placebo gaps. California is the black line; each grey line is a donor state treated as if it had passed Proposition 99. As in the paper's Figure 6, I drop placebos whose pre-period fit is more than five times worse than California's. By the late 1990s California's gap is the most negative of all.

On the right is the analogue of the paper's Figure 8, the ratio of post- to pre-period mean squared prediction error. California is the tallest bar, ranked first of 39.

## 11. Headline numbers [7:00]

Putting the numbers side by side: the gap in 2000 is 24.3 packs against the paper's 26. The average gap is 17.8 against almost 20, or 23 percent against 25. My pre-period fit is slightly worse, an MSPE of 3.8 against about 3, so the fit ratio is 90 rather than 130. But California is still first, and the p-value is identical.

So the qualitative result and the inference replicate exactly, and the point estimate is about 10 percent smaller.

## 12. Lessons [7:45]

A few lessons from doing this.

First, data vintage mattered less than I feared. The outcome series matched exactly, and even with every covariate built from different sources, the 2000 gap moved by about 2 packs.

Second, read the paper closely. Table 1 labels the income variable as log GDP per capita, but the text and the data appendix say log personal income. I followed the appendix.

Third, the weights are less stable than the counterfactual. Small data changes swapped Montana for Colorado but barely moved the synthetic path. So I'd interpret the path, not individual weights.

Fourth, the software can fail. When I moved to Massachusetts, `Synth`'s optimizer crashed on one placebo state, and I had to add a retry with looser tolerances.

And fifth, the sales data are by fiscal year, ending in June. Following the paper, the fiscal year that contains the January tax increase counts as the first treated year.

## 13. How this informs my project [8:45]

Massachusetts' Question 1 raised the tax from 26 to 51 cents on January 1st, 1993, and funded a tobacco control program. Because I use the same data, donor pool and code, differences from California can't be blamed on method.

Synthetic Massachusetts is mostly Connecticut and Delaware. The average gap over 1993 to 2000 is minus 18.5 packs, about 21 percent, very close to California's effect in proportional terms, but the permutation p-value is 0.077, so it's less decisive. In the project I also compare this with two-way fixed effects and synthetic difference-in-differences.

## 14. Takeaways [9:30]

To sum up, the main result of the paper replicates from public data: a 24-pack gap by 2000 against the paper's 26, and California ranks first among 39 placebos. The method's strength is transparency, since you can inspect the weights and the pre-period fit. Its limit is that with one treated unit, the smallest possible p-value is 1 over 39. Two issues carry over to my project: tax-paid sales are not smoking, because people can buy across state lines, and the treatment bundles a tax increase with a program, so the estimate is their combined effect.

Thank you.
