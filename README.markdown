Retjilp: Native Auto-retweet bot 
--------------------------------
<http://el-tramo.be/blog/retjilp>

Retjilp logs into your account, scans all the tweets from your following
list or another defined list for a set of matching words, and retweets 
the ones that match (using the native retweet API).
 
To install the script, run

    gem install retjilp

To use this script, you will need to have registered an application with
<http://twitter.com/apps> to get a consumer key and secret, and fill these 
values in a file `config` in the `.retjilp` dir in your homedir (i.e.
`~/retjilp`). The `config` file should have the following content:

    {
    	/*
    	 * Consumer key and secret.
    	 * Get this by registering a new (desktop) application at 
    	 * http://twitter.com/apps
    	 */
    	"consumer_key": "abcdeFghIjklMnOpQrStUv",
    	"consumer_secret": "abcdefgh123456789abcdefgh123456789abcdefg",
    
    	/*
    	 * The strings that a tweet should be matched against.
    	 * These strings are matched in lower case.
    	 */
    	"match": ["#sometag", "#someothertag", "someword"]
    
    	/*
    	 * List name from which statuses are retweeted.
    	 * Set this config value if you want to retweet only from 
    	 * this list instead of your following list.
    	 */
    	/* "retweet_from_list": "auto-retweet" */
    }

To start the script, run 

    retjilp
    
To get a list of command-line parameters, use the `--help` option.

The first time the script is run, it will ask you to authorize the application
in your Twitter account. After this is done, the script will automatically log
in the next time it is run.
