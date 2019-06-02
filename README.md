# nyt_tool
This is a shiny tool created by R to search news on New York Times based on NYT API.

Note: 

1) Due to changes of request format of NYT API, this tool may not not work for searching articles which were published in 2019. This issue will be address later in the future.
2) For privacy considerations, the default API key is removed from the code. To use this tool, you need to add your own API key into the code. To apply for an API key, please refer to https://developer.nytimes.com/

* Goal
The goal of this app is to search for articles from New York Times API on a certain date and output a list of article names. By clicking on an article name listed in the search results, a pop-up window is displayed with more information about the article, including the first image in the article, a head paragraph (snippet), and a hyperlink which directs the users to the article on the New York Times' website.

* Design features
1) The input panels include a date input where the users could select a specific date (the default is 2018-03-25) for the search, and also an optional input if the users want to use their own API key. To make the Shiny app more user friendly, I blocked the warnings of validating api key from function I created in task 2, and I prefer not to show error messages using functions like "validate" and "need" if users provided a wrong api key. This is because the goal of this shiny app is to provide a simple, user-friendly experience finding interesting articles from the NYTimes. If the user doesn't have a valid api key, I am happy to use mine for their search.
2) After selecting the inputs, the users can click the "Get Articles!" button and the results will be shown in the main panel. On the top of the results, there is a text output to show which date is selected for the search. And a list of article names is given and numbered. By clicking on any of the article names, a pop-up window will be shown with more details about the article. If the user wants to select another date, he needs to push the "Get Articles!" button again to get the updated results. For better app performance, no query will be made until the button is clicked. 



