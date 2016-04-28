#!/bin/bash

#FOLDER="$1"
#seq 1 100 | xargs -I @ curl -q 'http://wiki.dlang.org/DIP@?action=raw' -s -f -o "$FOLDER/@.media"

# temporarily ignore invalid
for f in 6 22 36 39 58 59 66 69 80 89 ; do
	rm -rf media/${f}.wiki
done

MEDIA_FOLDER="media"
MD_FOLDER="md"
mkdir -p "$MEDIA_FOLDER"
mkdir -p "$MD_FOLDER"

for f in $(find "$MEDIA_FOLDER" -type f | tr '\n' ' ') ; do

	filename=$(basename "$f")
	filename="${filename%.*}"
	file="${MD_FOLDER}/${filename}.md"

	# convert
	pandoc -f mediawiki -t markdown $f -o $file

	# remove category link
	sed -i 's/\[Category: DIP\](Category:_DIP "wikilink")//' "$file"

	# remove duplicate empty lines
	sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba' -i "$file"

	# fix code boxes
	sed 's/``` {.d}/```d/' -i $file

	# remove weird comments
	sed '/<\!-- -->/d' -i $file

	# remove trailing slashes
	sed 's/[`]\\$/`/g' -i $file

	# fix some nested lists
	sed 's/^[`]\*\(.*\)[`]/ -\1/' -i $file

	# remove awkward header
	sed "/^\s*\-+ \-*$/d" -i $file
	sed -r "/\s+-+\s+-+/d" -i $file

	# fix weird headers
	tmpFile=$(mktemp)
	perl -0777 -pe 's/((.|\n)*)(Title:)/\3/g' < $file > $tmpFile
	mv $tmpFile $file

	# fix yaml header start
	sed "1 i\---\nlayout: dip\nnr: $filename" -i $file

	# fix yaml header end
	tmpFile=$(mktemp)
	{ sed -n '/./!q;p'; echo "permalink: /DIP$filename"; echo '---'; echo; cat; } < $file > $tmpFile
	mv $tmpFile $file

	# properly indent yaml
	sed 's/^\s*\(\(Title\|DIP\|Version\|Status\|Created\|Last Modified\|Author\|Links\|Language\|Breaks\|Load\):\)\s*/\L\1 /' -i $file

	# remove dip, it was inconsistent
	sed '/^dip: \(.*\)/d' -i $file

	# remove stars around title in yaml header
	sed 's/^\(title: \)\*\*\(.*\)\*\*/\1\2/' -i $file
	sed 's/^\(title: \)\*\(.*\)\*/\1\2/' -i $file
	sed 's/^\(status: \)\*\*\(.*\)\*\*/\1\2/' -i $file
	sed 's/^last modified: \(.*\)/last-modified: \1/' -i $file
	sed 's/^\s*Related Issue:\s*\(.*\)/related-issue: \1/' -i $file

	# rewrite links
	links=$(grep "^links:" $file | sed 's/links: / - /' | sed 's/) \[/)\n - [/' \
		| sed 's/\[\(.*\)\](\(.*\))/"\1": \2/g' | sed -e 's/[]\/$*.^|[]/\\&/g' \
		| sed ':a;N;$!ba;s/\n/REPLACE_NEWLINE/g')
	#if [ -z "$links" ]; then
		#sed "s/^\(links:\) \(\[.*\](.*)\s*\)*/\1\n$links/" -i $file
		#sed "s/REPLACE_NEWLINE/\n/g" -i $file
	#fi

	sed '/^links: \(.*\)/d' -i $file

	# fix markdown links in header
	sed 's/\(.*: \)\[\(.*\)\](\(.*\))/\1\n - "\2": \3/g' -i $file

	# fix wikilinks
	sed 's/\[\(.*\)\]\((#.*\) "wikilink")/[{{site.baseurl}}\/\1]\2/g' -i $file

done
