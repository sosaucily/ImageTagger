root = exports ? this #This line sets up the public methods under the 'root' scope on the page's javascript
$ -> #JQuery initializer so this code runs after the page loads, when JQuery is ready

	path = document.location.pathname.substr(1)
	slash = path.indexOf("/")
	if slash isnt -1
		path = path.substr(0,slash)
	if !path? or path is ""
		path = "home"
	$('#nav_' + path).addClass("current")