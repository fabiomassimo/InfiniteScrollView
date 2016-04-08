## InfiniteScrollView
UIScrollView extension for infinite scrolling, in Swift. (Based on [https://github.com/pronebird/UIScrollView-InfiniteScroll](https://github.com/pronebird/UIScrollView-InfiniteScroll))

This extension swizzles `setContentOffset` and `setContentSize` on `UIScrollView`, so don't use it if that will be a problem for you.

### Basic Usage

UITableView:
```swift
override func viewDidLoad() {
	super.viewDidLoad()

	//Add the infinite scroll handler to the tableView
	tableView.addInfiniteScrollWithHandler { (scrollView) in
		self.loadMore()		//Whatever you need to do to put more data into your table view

		self.tableView.reloadData()

		//Call finishInfiniteScroll() to stop the animation and remove the loading indicator
		self.tableView.finishInfiniteScroll()
	}
}
```

### Attributions and Notes

This is a 100% direct reimplementation of [pronebird's UIScrollView-InfiniteScroll](https://github.com/pronebird/UIScrollView-InfiniteScroll) in pure Swift. I didn't want the overhead of the Objective-C code in a Swift-only project.

### To Do
* COMMENTS (_sigh_)
* Build out the custom loading indicator feature that the original implementation has
* Create a demo app
* CocoaPods and Carthage support
