//
//  InfiniteScrollView.swift
//	Created by Mike Glass (mike@glasseffect.com) on 2016-04-07
//	Released under MIT License (https://raw.githubusercontent.com/glasseffect/InfiniteScrollView/master/LICENSE)
//

import UIKit

let infiniteScrollAnimationDuration: NSTimeInterval = 0.35

private var infiniteScrollStateKey: UInt8 = 0
extension UIScrollView {
	var infiniteScrollState: InfiniteScrollState {
		get {
			return associatedObject(self, key: &infiniteScrollStateKey) { return InfiniteScrollState() }
		}
		set { associateObject(self, key: &infiniteScrollStateKey, value: newValue) }
	}
}

extension UIScrollView {		//Public methods
	func isAnimatingInfiniteScroll() -> Bool {
		return infiniteScrollState.loading
	}
	func addInfiniteScrollWithHandler(handler: (UIScrollView)->()) {
		infiniteScrollState.infiniteScrollHandler = handler

		guard !infiniteScrollState.initialized else { return }

		panGestureRecognizer.addTarget(self, action: #selector(UIScrollView.infiniteScrollHandlePanGesture(_:)))
		infiniteScrollState.initialized = true
	}
	func removeInfiniteScroll() {
		guard infiniteScrollState.initialized else { return }

		panGestureRecognizer.removeTarget(self, action: #selector(UIScrollView.infiniteScrollHandlePanGesture(_:)))
		infiniteScrollState.indicatorView?.removeFromSuperview()
		infiniteScrollState.indicatorView = nil
		infiniteScrollState.initialized = false
	}
	func finishInfiniteScroll() {
		finishInfiniteScrollWithCompletion(nil)
	}
	func finishInfiniteScrollWithCompletion(handler: InfiniteScrollHandler?) {
		if infiniteScrollState.loading {
			stopAnimatingInfiniteScrollWithCompletion(handler)
		}
	}
	func setInfiniteScrollIndicatorStyle(style: UIActivityIndicatorViewStyle) {
		infiniteScrollState.indicatorStyle = style
//		if infiniteScrollState.indicatorView is UIActivityIndicatorView {
			infiniteScrollState.indicatorView?.activityIndicatorViewStyle = style
//		}
	}
	func infiniteScrollIndicatorStyle() -> UIActivityIndicatorViewStyle {
		return infiniteScrollState.indicatorStyle
	}
	func setInfiniteScrollIndicatorView(indicatorView: UIActivityIndicatorView) {
		indicatorView.hidden = true
		infiniteScrollState.indicatorView = indicatorView
	}
	func infiniteScrollIndicatorView() -> UIActivityIndicatorView? {
		return infiniteScrollState.indicatorView
	}
	func setInfiniteScrollIndicatorMargin(margin: Double) {
		infiniteScrollState.indicatorMargin = margin
	}
	func infiniteScrollIndicatorMargin() -> Double {
		return infiniteScrollState.indicatorMargin
	}
}

extension UIScrollView {		//Private methods
	override public class func initialize() {
		struct Static { static var token: dispatch_once_t = 0; }
		dispatch_once(&Static.token) {
			let originalOffsetMethod = class_getInstanceMethod(self, Selector("setContentOffset:"));
			let swizzledOffsetMethod = class_getInstanceMethod(self, #selector(UIScrollView.infiniteScrollSetContentOffset(_:)));
			method_exchangeImplementations(originalOffsetMethod, swizzledOffsetMethod);

			let originalSizeMethod = class_getInstanceMethod(self, Selector("setContentSize:"));
			let swizzledSizeMethod = class_getInstanceMethod(self, #selector(UIScrollView.infiniteScrollSetContentSize(_:)));
			method_exchangeImplementations(originalSizeMethod, swizzledSizeMethod);
		}
	}
	@objc private func infiniteScrollHandlePanGesture(panGR: UIPanGestureRecognizer) {
		if panGR.state == .Ended {
			scrollToInfiniteIndicatorIfNeeded()
		}
	}
	@objc private func infiniteScrollSetContentOffset(contentOffset: CGPoint) {
		infiniteScrollSetContentOffset(contentOffset)

		if infiniteScrollState.initialized {
			infiniteScrollViewDidScroll(contentOffset)
		}
	}
	@objc private func infiniteScrollSetContentSize(contentSize: CGSize) {
		infiniteScrollSetContentSize(contentSize)

		if infiniteScrollState.initialized {
			positionInfiniteScrollIndicatorWithContentSize(contentSize)
		}
	}
	private func clampContentSizeToFitVisibleBounds(contentSize: CGSize) -> Double {
		let minHeight = Double(CGRectGetHeight(bounds)) - Double(contentInset.top) - originalBottomInset()
		return max(Double(contentSize.height), minHeight)
	}
	private func originalBottomInset() -> Double {
		let inset = Double(contentInset.bottom) - infiniteScrollState.extraBottomInset - infiniteScrollState.indicatorInset
		return inset
	}
	private func callInfiniteScrollHandler() {
		if let handler = infiniteScrollState.infiniteScrollHandler {
			handler(self)
		}
	}
	private func getOrCreateActivityIndicatorView() -> UIActivityIndicatorView {
		var activityIndicator = infiniteScrollIndicatorView()
		if activityIndicator == nil {
			activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: infiniteScrollIndicatorStyle())
			setInfiniteScrollIndicatorView(activityIndicator!)
		}
		if activityIndicator!.superview != self {
			addSubview(activityIndicator!)
		}
		return activityIndicator!
	}
	private func infiniteIndicatorRowHeight() -> Double {
		let indicator = getOrCreateActivityIndicatorView()
		let indicatorHeight = Double(CGRectGetHeight(indicator.bounds))
		let height = indicatorHeight + infiniteScrollIndicatorMargin() * 2
		return height
	}
	private func positionInfiniteScrollIndicatorWithContentSize(contentSize: CGSize) {
		let indicator = getOrCreateActivityIndicatorView()
		let contentHeight = clampContentSizeToFitVisibleBounds(contentSize)
		let indicatorRowHeight = infiniteIndicatorRowHeight()
		let center = CGPoint(x: contentSize.width * 0.5, y: CGFloat(contentHeight + indicatorRowHeight * 0.5))
		if !CGPointEqualToPoint(indicator.center, center) {
			indicator.center = center
		}
	}
	private func startAnimatingInfiniteScroll() {
		let indicator = getOrCreateActivityIndicatorView()

		positionInfiniteScrollIndicatorWithContentSize(contentSize)
		indicator.hidden = false
		indicator.startAnimating()

		let indicatorInset = infiniteIndicatorRowHeight()
		var contentInset = self.contentInset
		contentInset.bottom += CGFloat(indicatorInset)
		let adjustedContentHeight = clampContentSizeToFitVisibleBounds(contentSize)
		let extraBottomInset = adjustedContentHeight - Double(contentSize.height)
		contentInset.bottom += CGFloat(extraBottomInset)

		infiniteScrollState.indicatorInset = indicatorInset
		infiniteScrollState.extraBottomInset = extraBottomInset
		infiniteScrollState.loading = true

		setInfiniteScrollViewContentInset(contentInset, animated: true) { (finished) in
			if finished {
				self.scrollToInfiniteIndicatorIfNeeded()
			}
		}
	}
	private func stopAnimatingInfiniteScrollWithCompletion(handler: InfiniteScrollHandler?) {
		let indicator = infiniteScrollIndicatorView()!

		var insets = self.contentInset
		insets.bottom -= CGFloat(infiniteScrollState.indicatorInset)
		insets.bottom -= CGFloat(infiniteScrollState.extraBottomInset)
		infiniteScrollState.indicatorInset = 0
		infiniteScrollState.extraBottomInset = 0

		setInfiniteScrollViewContentInset(insets, animated: true) { (finished) in
			indicator.stopAnimating()
			indicator.hidden = true
			self.infiniteScrollState.loading = false

			if finished {
				let newY = self.contentSize.height - CGRectGetHeight(self.bounds) + self.contentInset.bottom
				if self.contentOffset.y > newY && newY > 0 {
					self.setContentOffset(CGPoint(x: 0, y: newY), animated: true)
				}
			}
			handler?(self)
		}
	}
	private func infiniteScrollViewDidScroll(contentOffset: CGPoint) {
		let contentHeight = clampContentSizeToFitVisibleBounds(contentSize)
		let actionOffset = contentHeight - Double(CGRectGetHeight(bounds)) + originalBottomInset()
		let hasActualContent = contentSize.height > 1

		guard hasActualContent else { return }
		guard dragging else { return }
		guard !infiniteScrollState.loading else { return }

		if contentOffset.y > CGFloat(actionOffset) {
			startAnimatingInfiniteScroll()

			let dispatchTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC)))
			dispatch_after(dispatchTime, dispatch_get_main_queue()) {
				self.callInfiniteScrollHandler()
			}
		}
	}
	private func scrollToInfiniteIndicatorIfNeeded() {
		guard !dragging else { return }
		guard infiniteScrollState.loading else { return }

		let contentHeight = clampContentSizeToFitVisibleBounds(contentSize)
		let indicatorRowHeight = infiniteIndicatorRowHeight()

		let minY = contentHeight - Double(CGRectGetHeight(bounds)) + originalBottomInset()
		let maxY = minY + indicatorRowHeight

		if contentOffset.y > CGFloat(minY) && contentOffset.y < CGFloat(maxY) {
			setContentOffset(CGPoint(x: 0, y: maxY), animated: true)
		}
	}
	private func setInfiniteScrollViewContentInset(contentInset: UIEdgeInsets, animated: Bool, completion: ((Bool)->())?) {
		let animations = { self.contentInset = contentInset }
		if animated {
			UIView.animateWithDuration(infiniteScrollAnimationDuration, delay: 0, options: [.AllowUserInteraction, .BeginFromCurrentState], animations: animations, completion: completion)
		} else {
			UIView.performWithoutAnimation(animations)
			completion?(true)
		}
	}
}

extension UIScrollView {		//Support
	class InfiniteScrollState {
		var initialized = false
		var loading = false
		var indicatorView: UIActivityIndicatorView?
		var indicatorStyle = UIActivityIndicatorViewStyle.Gray
		var extraBottomInset = 0.0
		var indicatorInset = 0.0
		var indicatorMargin = 11.0
		var infiniteScrollHandler: InfiniteScrollHandler?

		init() { }
	}
	func associatedObject<ValueType: AnyObject>(base: AnyObject, key: UnsafePointer<UInt8>, initialiser: () -> ValueType) -> ValueType {
		if let associated = objc_getAssociatedObject(base, key) as? ValueType { return associated }
		let associated = initialiser()
		objc_setAssociatedObject(base, key, associated, .OBJC_ASSOCIATION_RETAIN)
		return associated
	}
	func associateObject<ValueType: AnyObject>(base: AnyObject, key: UnsafePointer<UInt8>, value: ValueType) {
		objc_setAssociatedObject(base, key, value, .OBJC_ASSOCIATION_RETAIN)
	}
	typealias InfiniteScrollHandler = (UIScrollView)->()
}
