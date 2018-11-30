# 🌀Insoluble

This is my entry for [NaNoGenMo 2018](https://github.com/NaNoGenMo/2018).
You can read the generated novel here:
[Angela's Claustrum](https://github.com/kranzky/insoluble/blob/master/claustrum.md)

## How It Works

The general idea was to write some language modelling software, in C and Ruby,
to generate a new novel using
[Insoluble](https://github.com/kranzky/insoluble/blob/master/insoluble.md),
the novel I wrote for NaNoWriMo 2015, as a template.

### Segmentation

I started out by downloading the
[Gutenberg Dataset](https://web.eecs.umich.edu/~lahiri/gutenberg_dataset.html)
and writing some code to iterate over all texts in the corpus, yielding a list
of chapters, each comprised of multiple paragraphs, with paragraphs consisting
of a sequence of sentences, each tagged as being exposition or dialogue. Various
heuristics were used to decide whether a line was part of a story or not (as a
lot of the Gutenberg texts contain headers and footers outside the scope of the
story), and to decide what comprises a sentence. I just iterated on it all until
I was happy with the results.

### Keyword Association

The next step was to create a
[template](https://github.com/kranzky/insoluble/blob/master/template.txt)
for the novel I wanted to generate. I did this by taking _Insoluble_ and running
it through the segmentation filter, then cleaning up the results by hand. I then
wrote a program to generate a list of keywords for each sentence in the
template.

I sank many days of experimentation into this task, going back-and-forth, trying
different techniques. It's important to me that the results look good without
any manual fine-tuning, so I wanted to select the best algorithm based on my
personal evaluation of the results (which is a form of fine-tuning, of course,
but of a different kind). The final algorithm works like this:

* Scan _Insoluble_ to build a dictionary of normalised words (i.e. uppercase with most punctuation removed) that appear in the template.
* Iterate through all of the _Gutenberg Dataset_, training a language model that captures the likelihood of a normalised word appearing in a sentence given that some other normalised word also appears in that sentence. Separate models are trained for exposition versus dialogue.
* For each sentence in the template, measure the total [NPMI](https://en.wikipedia.org/wiki/Pointwise_mutual_information#Normalized_pointwise_mutual_information_(npmi)) between each normalised word in the sentence and all the words in the _Gutenberg Dataset_.
* Take the three normalised words with the highest total _NPMI_ and repeat the process, this time constraining the results to normalised words that are known to appear in the template.
* Select the best five keywords from the results, and write them to the output, together with the number of normalised words in the original sentence.

So, for example, this sentence in the template:

```
exposition:My wife burst out of bed and entered the bathroom, barely looking my way in the rush.
```

Would be turned into the following three keywords, based on associations inferred from the _Gutenberg Dataset_:

```
PILOSA CONGLOMERATUS WHITE-RIMMED
```

And these would be used to generate the final keywords, using the same associations:

```
exposition;15:RUSH WOOD LAUGHTER BURST FOLLOWING
```

This is kinda-sorta like "translating" the sentence from _Insoluble_ to
_Gutenberg_ and back again, using only statistics inferred from _Gutenberg_,
yielding some keywords that we can then use to constrain sentence generation,
along with a target word count that can be used to choose between multiple
generations (the `18` in the example above).

Initially I only performed the process once, always ending up with lists of
keywords that included a character names and _hapax legomena_ from _Gutenberg_,
iterating madly to change the algorithm to make these unlikely, eventually
building a blacklist of words to prevent them from being used, as their presence
invariably made the resulting generated text a lot more disjointed and random
than I would have liked. Eventually I tried performing the process twice, and
the results were immediately much better.

You can view the full list of
[keywords](https://github.com/kranzky/insoluble/blob/master/keywords.txt)
<- there.

### Sentence Generation

The next step was to take five keywords, and a target sentence count, and
generate a sentence that contains as many of the keywords as possible while
being as close to the target word count as possible.

I achieved this by coding what I call a "Fractal Language Model". For all word
pairs `A-B` in a particular sentence, regardless of how far they're separated,
it infers statistics over which word may appear immediately before `B` (with a
special unprintable word being used in the case where `A` and `B` are adjacent.

This model is then easily used to generate candidate sentences, which was done
as follows:

* For each possible permutation of five keywords (there are 120 of them), generate 100 sentences. Of course, some permutations may yield zero generations, as particular keyword pairs may never have been observed in _Gutenberg_.
* Do the same for all permutations of 4, 3, 2 and 1 keywords as well.
* Score each generation, using a heuristic that prefers more keywords, provided that the number of words in the sentence isn't too different from the target number of words.
* Select the generation with the highest score.

For instance, for these keywords:

```
exposition;15:RUSH WOOD LAUGHTER BURST FOLLOWING
```

The resulting generation is:

```
exposition;5,0:THEIR LAUGHTER OF WOOD OF THE SILENT LAUGHTER BUT THE RUSH BURST AWAY NORTHWARDS FOLLOWING
```

This generation contains all five keywords, and is exactly the same word length as
the original sentence from the template (hence the `5;0` in the results).

You can view the full list of
[generated sentences](https://github.com/kranzky/insoluble/blob/master/generated.txt)
<- there.

### Repairing

The final step is to repair the generations to de-normalise the words and insert
punctuation back where it should be. This is done by inferring a couple of new
language models from _Gutenberg_:

* The first model infers which punctuation symbols should occur between adjacent pairs of normalised words.
* The second model infers which de-normalised form of a word should be used, given the previous word and the punctuation that occurs after it.
* These models are used to generate up to 100 repaired sentences, with a heuristic being used to score the generation (doing nothing more than trying to make sure quotation marks are balanced).

For example, this generation:

```
exposition;5,0:THEIR LAUGHTER OF WOOD OF THE SILENT LAUGHTER BUT THE RUSH BURST AWAY NORTHWARDS FOLLOWING
```

is repaired to:

```
Their laughter of wood of the silent laughter, but the rush burst away northwards, following.
```

### Final Generation

Repaired sentences are joined back into paragraphs, and a template is used to
add the title, author and chapter labels. And that's the entire process that was
used to generate
[Angela's Claustrum](https://github.com/kranzky/insoluble/blob/master/claustrum.md)!

## Future Work

The language model I use for generating sentences could be better; the results
contain too many discontinuities for my liking (worse than a 2nd-order Markov
Model). I coded up a better language model and performed some tests, then tried
running it on the entirety of _Gutenberg_. After a couple of days, it had barely
chewed through the first 5% of sentences, and my laptop had ground to a halt at
100% memory and 100% CPU.

So I fired up a high-memory AWS instance and tried again. The progress after a
couple of days was not much better. I upgraded to a compute-optimised instance,
and made my code multi-threaded, but it's clear that generation won't be
finished before the deadline.

Once generation is done, I'll add a second version of the generated novel to
this repo to allow results to be compared.

Copyright (c) 2018 Jason Hutchens. See [UNLICENSE](https://github.com/kranzky/insoluble/blob/master/UNLICENSE) for further details.
