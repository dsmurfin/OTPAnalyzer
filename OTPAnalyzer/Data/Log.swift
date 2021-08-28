//
//  Log.swift
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

import Foundation

import Cocoa

/**
 Log Delegate
 
 Required methods for objects implementing this delegate.

*/

protocol LogDelegate: AnyObject {
    
    /**
     Called when a new log message has been received.
     
     - Parameters:
        - message: The log message received.

    */
    func newLogMessage(_ message: String)
    
    /**
     Called when logs have been cleared.
    */
    func clearLogs()
    
}

// MARK: -
// MARK: -

/**
 Log
 
 Responsible for storage and notification of log messages.
 
*/

public final class Log {
    
    /**
     MessageType
     
     Enumerates the types of log messages.
     
    */
    enum MessageType {
        
        /// Used for informational messages.
        case info
        
        /// Used for socket errors.
        case socket
        
        /// Used for unknown errors
        case unknown
        
        /// Used for layer errors in the protocol.
        case protocolLayer
        
        /// Used for sequence errors in the protocol.
        case protocolSequence
        
        /// Used for unknown errors in the protocol.
        case protocolUnknown
        
        /// Used for debug errors.
        case debug

    }
    
    /// The serial dispatch queue used for creating log messages.
    private static let queue = DispatchQueue(label: "com.danielmurfin.OTPAnalyzer.logQueue")

    /// Attributes used for log messages when displayed to a user.
    static let attributes = [NSAttributedString.Key.font : NSFont(name: "Monaco", size: 11.0)!, NSAttributedString.Key.foregroundColor : NSColor.labelColor]
    
    /// The maximum total size for log messages before they are cleared.
    static let maxSize = 5000
    
    /// The delegate to be notified when changes to the logs occur.
    weak var delegate: LogDelegate?
    
    /// Whether errors should be logged.
    var logErrors: Bool {
        get { Self.queue.sync { _logErrors } }
        set (newValue) { return Self.queue.sync { _logErrors = newValue } }
    }
    
    /// Whether errors should be logged (internal).
    private var _logErrors: Bool = false
    
    /// Whether debug errors should be logged.
    var logDebug: Bool {
        get { Self.queue.sync { _logDebug } }
        set (newValue) { return Self.queue.sync { _logDebug = newValue } }
    }
    
    /// Whether debug errors should be logged (internal).
    private var _logDebug: Bool = false
    
    /// Whether debug socket errors should be logged.
    var logDebugSocket: Bool {
        get { Self.queue.sync { _logDebugSocket } }
        set (newValue) { return Self.queue.sync { _logDebugSocket = newValue } }
    }
    
    /// Whether debug socket errors should be logged (internal).
    private var _logDebugSocket: Bool = false

    /**
     Adds a new message of the type specified to the logs.
     
     - Parameters:
        - message: The message to be logged.
        - type: The `MessageType` of the message.
     
    */
    func add(message: String, ofType type: MessageType) {
                    
        switch type {
        case .info:
            break
        case .unknown, .protocolLayer, .protocolSequence, .protocolUnknown:
            guard logErrors else { return }
        case .debug:
            guard logDebug else { return }
        case .socket:
            guard logDebug && logDebugSocket else { return }
        }
        
        Self.queue.async {
            
            // get the formatted date string
            let dateString = Date().logDateFormatter()
            
            // create a message string
            var newMessage = "[\(dateString)] "
                
            switch type {
            case .info:
                newMessage += "[Info] "
            case .socket:
                newMessage += "[Socket] "
            case .unknown:
                newMessage += "[Error] "
            case .protocolLayer:
                newMessage += "[Protocol Layer] "
            case .protocolSequence:
                newMessage += "[Protocol Sequence] "
            case .protocolUnknown:
                newMessage += "[Protocol Unknown] "
            case .debug:
                newMessage += "[Debug] "
            }
              
            newMessage += message + "\n"

            // notify the delegate of the new message
            self.delegate?.newLogMessage(newMessage)

        }
        
    }
    
    /**
     Resets the logs back to a clean state.
    */
    func reset() {
        
        // notify the delegate that logs have been cleared
        Self.queue.async {
            self.delegate?.clearLogs()
        }
        
        // add the app and version information
        addVersion()
        
    }
    
    /**
     Adds the app name and version to the logs.
    */
    func addVersion() {
        
        // get the current version number
        guard let currentVersionNumber = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }

        // get the build number
        guard let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else { return }
        
        add(message: "OTPAnalyzer " + currentVersionNumber + " Build " + buildNumber, ofType: .info)
        
        // create a date formatter
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        
        // get the date formatted
        let date = formatter.string(from: Date())
        
        // add copyright information
        add(message: "Copyright \(date) Daniel Murfin. All rights reserved.", ofType: .info)

    }
    
}

// MARK: -
// MARK: -

/**
 Date Extension
 
 Extensions to `Date` for log messages.
 
*/

extension Date {
    func logDateFormatter() -> String {
        return DateFormatter.LogDateFormatter.string(from: self)
    }
}

// MARK: -
// MARK: -

/**
 Date Formatter Extension
 
 Extensions to `DateFormatter` for log messages.
 
*/

extension DateFormatter {
    fileprivate static let LogDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
