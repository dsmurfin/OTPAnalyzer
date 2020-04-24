//
//  ShortTitleCell.swift
//
//  Copyright (c) 2020 Daniel Murfin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Cocoa

/**
 Short Title Popup Button Cell
 
 Displays a shortened title for this popup button cell using a dictionary represented object for the title.

*/

class ShortTitleCell: NSPopUpButtonCell {
    
    /// The key for the short title object in the dictionary.
    static var shortTitle = "shortTitle"
    
    open override func drawTitle(_ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView) -> NSRect {

        var attributedTitle = title

        if let popUpButton = self.controlView as? NSPopUpButton, let object = popUpButton.selectedItem?.representedObject as? Dictionary<String, String> {
            if let shortTitle = object[Self.shortTitle] {
                attributedTitle = NSAttributedString(string:shortTitle, attributes:title.attributes(at:0, effectiveRange:nil))
            }
        }
        
        return super.drawTitle(attributedTitle, withFrame:frame, in:controlView)
        
    }
    
}
