# reddit whisky exposé

*made by [/u/rhabarba](https://reddit.com/u/rhabarba)*

## License:

[WTFPL](http://www.wtfpl.net/txt/copying/)

## Requirements:

- Racket
- the YAML module (`raco pkg install yaml`)
- a file named `whiskies.yaml` built like this:

    meta:
        - username: your-reddit-username
    
    whiskies:
        - name: Foo Bar
          age: 12
          price: $42
          alcvol: 42.6
          region: Speyside
          subreddit: scotch
          commentsid: 7gg3o9
          rating: 100
    
        - name: Quux
          age: NAS
          subreddit: worldwhisky
          commentsid: abcdef

The `meta` field is mandatory.

All whisky fields except `name`, `subreddit` and `commentsid` (which is the ID
part of the reddit thread URL) are optional, the table will remain empty in the
particular fields.

## Notes:

For efficiency reasons, the list is read once on startup. Restart the server if
you changed your YAML file. (This could be automatic if you use a VCS, e.g. a
post-commit hook.)