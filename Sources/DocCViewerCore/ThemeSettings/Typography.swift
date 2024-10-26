//
//  File.swift
//  DocCViewer
//
//  Created by Noah Kamara on 26.10.24.
//

import Foundation

/// Settings related to typography.
public struct Typography: Encodable {
    /// The CSS font-family value to be used globally for text in documentation.
    public var htmlFont: String? = nil
    
    /// The CSS font-family value to be used for monospaced code-voice text in documentation.
    public var htmlFontMono: String? = nil
}
