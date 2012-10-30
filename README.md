# General useage

    $ scholar-search.pl data.csv > data-pdfs.csv

    $ get-pdfs.pl data-pdfs.csv 

    $ ocr

    $ citations.pl data-pdfs.csv > citations.csv

# Input format

Many of these scripts operate on an input file. The file format is CSV (comma-separated values). Each row specifies a publication. The fields for each row are:

  - GUID (a globally-unique identifier for each row)

  - Authors

  - Title

  - Year

  - Source

  - Primary Link (a URL, typically a PDF link)

  - Link Title (other links, just their titles; separated by semicolons)

  - Link URLs (other links, their URLs; separated by semicolons)

  - Topics (separated by semicolons; e.g., "Robots;Science Fiction")

  - Tags (separated by semicolons; e.g., "classic;technical")

  - Body (text, no linebreaks)

  - NodeID (numeric unique id, like GUID)

  - Cites (list of NodeIDs that this publication cites; separated by semicolon)

# Google Scholar PDF finder

Given a CSV file containing publication information, the `scholar-search.pl` script searches Google Scholar and attempts to extract PDF links to each publication. IJCAI links are found by a separate mechanism.

Google Scholar may periodically require that a captcha to be answered. If this happens, the script shows the captcha and allows the user to enter the answer. Then the script continues its search.

## Requirements

Perl, LWP::UserAgent, WWW::Mechanize, HTML::TreeBuilder, My::Google::Scholar, Text::LevenshteinXS, Text::CSV.

## Example usage

    $ ./scholar-search.pl input.csv > output.csv

The resulting file `output.csv` has PDF links added to the Primary Link and Link Titles/URLs fields in the CSV file.

# PDFs downloader

Given a CSV file containing publication information, including in particular a URL in the Primary Link field, the `get-pdfs.pl` script attempts to download the associated PDF. The Primary Link may not point directly to a PDF. This script can still download the PDF if the link points to ScienceDirect, JSTOR, ACM Digital Library, Springer Link, IEEE Explore, Wiley, AMS, and Citeseer. Of course, for this script to work on these databases, the user must have access (typically via a subscription that identifies the user by their IP address).

## Requirements

Perl, WWW::Mechanize, HTML::TreeBuilder, Text::CSV, File::LibMagic.

## Example usage

    $ ./get-pdfs.pl input.csv

PDFs are downloaded to `[nodeid].pdf` files in the current directory.

# OCR

About this script...

## Requirements

1. Bash to run the script
2. [Tesseract OCR engine](http://code.google.com/p/tesseract-ocr/) (Apache 2.0 license)
3. pdftotext, pdfimages (poppler-utils; GPL license)
4. [unpaper](http://unpaper.berlios.de/) (GPL license)
5. [ImageMagick](http://www.imagemagick.org/script/index.php) (Apache 2.0 license)

## Example usage

Convert PDFs in the current directory:

    ocr

Convert PDFs from a different directory (output to the current directory):

    ocr /path/to/pdfs/directory/

Convert one PDF:

    ocr mypdf.pdf


# Citations finder

About this script...