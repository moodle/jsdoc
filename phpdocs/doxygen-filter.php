#!/usr/bin/env php
<?php
$source = file_get_contents($argv[1]);

// Note: Here there is a good collection of filters: https://github.com/AbcAeffchen/doxygen-php-filters

// T01: SOLVED since 1.8.16. Works perfectly.
//           INHERIT_DOCS does not seem to be working. Need to implement something
//           automated using @copydoc xxx::yyy(). It would require to find all the parentship
//           relations between classes and then blindly (without verifying if the method
//           exists) copying the parent::method()
// TODO T02: If a class is missing docs, copy them from the file.
// NOTE: Surely the issues above require moving from current regexp to a tokenizer as filter.
// TODO T03: Show file paths? Only final filenames are shown.
// T05: DONE: Now we replace all backslashes in comment lines by ::
//           Replace all backslashes in all phpdocs, to get linking working better with namespaces. Example core\update\info
// TODO T06: Look for unsupported tags. They seem to break documentation. Look for solution:
//           - category
//           - subpackage
//           - ... look warnings for more
//           Once done, verify, for example, has_capability.
// TODO T07: Support traits, surely via filter. Some ideas @
//           https://conetix.com.au/blog/simple-guide-using-traits-laravel-5/#documenting-traits-with-doxygen
// TODO T08: Feed EXCLUDE_PATTERNS with env varibale calculated from outside.
// TODO T09: Wrap everything into a script doing:
//           1) Pre-process tasks: generating excludes, bits that cannot be done via filter. components map...
//           2) Run doxygen itself.
//           3) Post-process tasks: Adjust files with paths, verify that there isn't any fill path, package, docset...

// If the file is a lang file for sure it's not a good candidate for any API. Nothing to process.
// Note we can opt to exclude all */lang/xx/* files from config. This is just a 2nd measure against them.

$regexp = '#/lang/[a-z_]*/#';
if (preg_match($regexp, $argv[1]) !== 0) {
    // TODO: Consider returning a fixed paragraph, or adding the file to a non-api group.
    error_log($argv[1] . ':0: notice: skipping lang file. Not suitable for APIs');
    echo '';
    die;
}

// If the file is a CLI_SCRIPT for sure it's not a good candidate to look for any API within it. Nothing to process.

$regexp = '#define.*?CLI_SCRIPT.*?true#';
if (preg_match($regexp , $source) !== 0) {
    // TODO: Consider returning a fixed paragraph, or adding the file to a non-api group.
    error_log($argv[1] . ':0: notice: skipping CLI_SCRIPT. Not suitable for APIs');
    echo '';
    die;
}

// If the file is including config.php for sure it's a front-end script and not a good candidate either. Nothing to process.

$regexp = '#\n *require(_once)?.*?config\.php#';
if (preg_match($regexp , $source) !== 0) {
    // TODO: Consider returning a fixed paragraph, or adding the file to a non-api group.
    error_log($argv[1] . ':0: notice: skipping front-end script. Not suitable for APIs');
    echo '';
    die;
}

// Add the @file tag to the very first phpdoc block in the file. Required to get all the global-scope stuff processed.

$regexp = '#/\*\*(.*)@file#';
if (preg_match($regexp , $source) === 0) { // Only if it does not exist.
    $regexp = '#/\*\*(.*)#';
    $replac = '/**${1} @file ' . $argv[1];
    $source = preg_replace($regexp, $replac, $source, 1);
}

// Get rid of any existing @name tag. They are used as headers for member grouping. We don't use it.

$regexp = '#@name\s+.*#';
$replac = '';
$source = preg_replace($regexp, $replac, $source);

// Transform php @var and @global phpdoc comments into C alternative.
// Ideas from: http://stackoverflow.com/questions/4325224/doxygen-how-to-describe-class-member-variables-in-php/8472180#8472180
// Example:
//     /**
//      * @var type description
//      */
//      public static $variable;
// Into:
//     /**
//      * description
//      */
//      public static type $variable

$regexp = '#(\@(var|global)\s+)([^\s]+)(\s+(.*?))(\*/\s+)(((var|global|public|protected|private|static)\s+)*)(\$[^;]+;)*#ms';
//$replac = '${1}${4}${6}${7}${3} ${10}';
$replac = '${4}${6}${7}${3} ${10}';
$source = preg_replace($regexp, $replac, $source);

// Transform php @return phpdoc comment into @retval, that can have types.
// Note it's not perfect because types are interpreted as values (hence aren't linked to declaration).

$regexp = '#@return(\s+)#';
$replac = '@retval${1}';
$source = preg_replace($regexp, $replac, $source);

// Add the @namespace block to all namespaces, replacing backslashes by :: (only in the comment block just added).

$regexp = '#namespace\s+(.*?);#';
$source = preg_replace_callback($regexp, function ($matches) {
    $converted = str_replace('\\', '::', $matches[1]);
    return $matches[0] . " /** @namespace $converted &nbsp;*/";
}, $source);

// Remove all the backslashes after whitespace or pipe.

$regexp = '#(\s+|\|)\\\\#';
$replac = '${1}';
$source = preg_replace($regexp, $replac, $source);

// Replace backslashes by :: in all comment lines, so they are better linked.
// TODO: We need to post-process all HTML pages to move them back to backslashes display.
// Workaround proposed @ https://github.com/doxygen/doxygen/issues/8384 does not
// work for params and return values only for text in general.

$regexp = '#((\/\/|\*)[^\n\\\\]*)(\\\\\\S*)#';
$source = preg_replace_callback($regexp, function ($matches) {
    return $matches[1] . str_replace('\\', '::', $matches[3]);
}, $source);

// Find the @package used by the @file docblock and enclose the whole file into a @addtogroup.
// TODO: Maybe add support for subpackages as subgroups.

$regexp = '#(/\*\* @file.*?)(\@package\s+([^\n]*)?)(.*?\*/)#ms';
if (preg_match($regexp, $source, $matches)) {
    $package = trim($matches[3]);
    if (!empty($package)) {
        // Replace the 3 first lines in the file after <?php by the @addtogroup tag
        $regphp = '#^(.\?php[^\n]*\n)([^\n]*\n){3}#ms'; // 3 first lines after the php one.
        $replac = '${1}/** @addtogroup ' . "$package $package \n * @{\n */\n";
        $source = preg_replace($regphp, $replac, $source);
        // Add, at the end of the file, the closing of the @addtogroup tag.
        $source .= '/** @} */';
        // Finally, delete the @package tag, to avoid files being assigned to the same group twice.
        $source = preg_replace($regexp, '${1}${4}', $source);
    }
}

// Replace all the @package tags by @ingroup.
// TODO: Maybe add support for subpackages as subgroups.

$regexp = '#\@package\s+([^\n]*)#';
$replac = '@ingroup ${1}';
$source = preg_replace($regexp, $replac, $source);

// Change the @access (private|protected|public) tags by corresponding @private|@protected|@public ones.

$regexp = '#\@access\s+(private|protected|public)#';
$replac = '@${1}';
$source = preg_replace($regexp, $replac, $source);

// Change all the MDL/CONTRIB... codes to Tracker URLs. Don't use the full regexp in filter but a reduced one.

$regexp = '#([^/])((?:MDL|MDLSITE|CONTRIB|MDLQA|MDLTEST)-\d+)\b#';
$replac = '${1}<a class="el" href="https://tracker.moodle.org/browse/${2}">${2}</a>';
$source = preg_replace($regexp, $replac, $source);

// Change all the non-inline @link tags to @externalurl. It will be converted to links by xrefitem and ALIASES.

$regexp = '#(\*\s+)\@link(\s+\S+)#';
$replac = '${1}@externalurl${2}';
$source = preg_replace($regexp, $replac, $source);

// Change all the inline {@link} tags to their corresponding @link and @endlink (or plain URLs) alternative.

$regexp = '#\{\@link\s+([^ \n}]+)\s*([^ \n}]*)(\s*)\}#';
$source = preg_replace_callback($regexp, function ($matches) {
    if (preg_match('#([a-zA-Z]+:\/\/|mailto\:)\S*#', $matches[1])) {
        // The link is a URL, let's create it with HTML.
        $src = $matches[1];
        $txt = isset($matches[2]) ? $matches[2] : $matches[1];
        return '<a class="el externalurl" href="' . $src . '">' . $txt . '</a>' . ($matches[3] ?? '');
    } else {
        // The link is to something else (page, class, method...), use @link...@endlink.
        $link = $matches[1];
        $desc = isset($matches[2]) ? trim(' ' . $matches[2]) : '';
        return '@link ' . $link . $desc . ' @endlink' . ($matches[3] ?? '');
    }
}, $source);

// Convert all traits to interfaces with trait_ prefix so, at very least, they are detected.
// TODO: Surely later we can do classes using them to make them to implment them for easier viewing.

$regexp = '#^trait([\s]+([\S]+[\s]*)){#';
$replace = 'interface trait_$2{';
$source = preg_replace($regexp, $replace, $source);

echo $source;
