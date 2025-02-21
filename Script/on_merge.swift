//
//  on_merge.swift
//
//  A simple script to process files and generate a README.md file.
//  It's not supposed to be pretty, it's supposed to work. 😉
//
//  Created by Piotr Jeremicz on 4.02.2025.
//

import Foundation

// MARK: - Constants
let year = 2020
let name = "Swift Student Challenge"

let templateFileName = "Template.md"
let submissionsDirectoryName = "Submission"

let template = #"""
Name:
Status:
Technologies:

AboutMeUrl:
SourceUrl:
VideoUrl:

<!---
EXAMPLE
Name: John Appleseed
Status: Submitted <or> Winner <or> Distinguished <or> Rejected
Technologies: SwiftUI, RealityKit, CoreGraphic

AboutMeUrl: https://linkedin.com/in/johnappleseed
SourceUrl: https://github.com/johnappleseed/wwdc2025
VideoUrl: https://youtu.be/ABCDE123456
-->

"""#

// MARK: - Find potential Template.md files
let fileManager = FileManager.default
let rootFiles = (try? fileManager.contentsOfDirectory(atPath: ".")) ?? []
let potentialTemplateFiles = rootFiles.filter { $0.hasSuffix(".md") && $0 != "README.md" }

// MARK: - Load potential template files
var potentialTemplates = [(filename: String, content: String)]()
for file in potentialTemplateFiles {
    guard let content = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
    potentialTemplates.append((filename: file, content: content))
}

// MARK: - Validate potential template files and prepare new filename
var validatedTemplates = [(originalFilename: String, newFilename: String, content: String)]()
for potentialTemplate in potentialTemplates {
    let lines = potentialTemplate.content.split(separator: "\n")
    
    guard lines.count >= 6 else { continue }
    guard lines[0].hasPrefix("Name:") else { continue }
    guard lines[1].hasPrefix("Status:") else { continue }
    guard lines[2].hasPrefix("Technologies:") else { continue }
    guard lines[3].hasPrefix("AboutMeUrl:") else { continue }
    guard lines[4].hasPrefix("SourceUrl:") else { continue }
    guard lines[5].hasPrefix("VideoUrl:") else { continue }
    
    let newFilename = lines[0]
        .replacingOccurrences(of: "Name:", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
        .replacingOccurrences(of: " ", with: "") + ".md"
    
    validatedTemplates.append(
        (
            originalFilename: potentialTemplate.filename,
            newFilename: newFilename,
            content: potentialTemplate.content
        )
    )
}

// MARK: - Create Submission directory
if !fileManager.fileExists(atPath: submissionsDirectoryName) {
    try? fileManager.createDirectory(atPath: submissionsDirectoryName, withIntermediateDirectories: true, attributes: nil)
}

// MARK: - Relocate validated template file and rename it
for validatedTemplate in validatedTemplates {
    do {
        // First remove, later create new one. If the removal will fail the result will not produce two independent files.
        try fileManager.removeItem(atPath: "\(validatedTemplate.originalFilename)")
        try validatedTemplate.content.write(
            toFile: "\(submissionsDirectoryName)/\(validatedTemplate.newFilename)",
            atomically: true,
            encoding: .utf8
        )
    } catch {
        continue
    }
}

// MARK: - Clean template file
try? template.write(toFile: "Template.md", atomically: true, encoding: .utf8)

// MARK: - Submission model
struct Submission {
    let name: String
    let status: Status
    let technologies: [String]
    
    let aboutMeUrl: URL?
    let sourceUrl: URL?
    let videoUrl: URL?
    
    enum Status: String {
        case submitted = "Submitted"
        case accepted = "Accepted"
        case winner = "Winner"
        case distinguished = "Distinguished"
        case rejected = "Rejected"
        case unknown = "Unknown"
        
        var iconURLString: String {
            switch self {
            case .submitted:
                "https://img.shields.io/badge/submitted-slategrey?style=for-the-badge"
            case .accepted:
                "https://img.shields.io/badge/accepted-green?style=for-the-badge"
            case .winner:
                "https://img.shields.io/badge/winner-green?style=for-the-badge"
            case .distinguished:
                "https://img.shields.io/badge/distinguished-goldenrod?style=for-the-badge"
            case .rejected:
                "https://img.shields.io/badge/rejected-firebrick?style=for-the-badge"
            case .unknown:
                "https://img.shields.io/badge/unknown-grey?style=for-the-badge"
            }
        }
    }
    
    var row: String {
        let nameRow = if let aboutMeUrl {
            "[\(name)](\(aboutMeUrl.absoluteString))"
        } else {
            "\(name)"
        }
        
        let sourceRow: String = if let sourceUrl {
            "[GitHub](\(sourceUrl.absoluteString))"
        } else {
            "-"
        }
        
        let videoUrl = if let videoUrl {
            "[\(videoUrl.absoluteString.contains("youtu") ? "YouTube" : "Video")](\(videoUrl.absoluteString))"
        } else {
            "-"
        }
        
        let technologiesRow = technologies.joined(separator: ", ")
        
        let statusRow: String = "![\(status.rawValue)](\(status.iconURLString))"
        
        return "|" + [
            nameRow,
            sourceRow,
            videoUrl,
            technologiesRow,
            statusRow
        ].joined(separator: "|") + "|"
    }
}

// MARK: - Load all submission files into Submission model
let submissionFiles = (try? fileManager.contentsOfDirectory(atPath: submissionsDirectoryName)) ?? []

func toValue(_ string: String.SubSequence, key: String) -> String? {
    let value = String(string)
        .replacingOccurrences(of: key, with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    return value.isEmpty ? nil : value
}

extension URL {
    var isValid: Bool {
        self.scheme != nil && self.host != nil
    }
}

var submissions = [Submission]()
for submissionFile in submissionFiles {
    guard let content = try? String(contentsOfFile: "\(submissionsDirectoryName)/\(submissionFile)", encoding: .utf8) else { continue }
    
    let lines = content.split(separator: "\n")
    guard lines.count >= 6 else { continue }
    
    let name: String? = if lines[0].hasPrefix("Name:") {
        toValue(lines[0], key: "Name:")
    } else { nil }
    
    let status: Submission.Status? = if lines[1].hasPrefix("Status:"), let value = toValue(lines[1], key: "Status:") {
        .init(
            rawValue: value
        )
    } else { nil }
    
    let technologies: [String] = if lines[2].hasPrefix("Technologies:"), let value = toValue(lines[2], key: "Technologies:") {
        value.split(separator: ", ").map { String($0) }
    } else { [] }
    
    let aboutMeUrl: URL? = if lines[3].hasPrefix("AboutMeUrl:"), let value = toValue(lines[3], key: "AboutMeUrl:"), let url = URL(string: value), url.isValid {
        url
    } else { nil }
    
    let sourceUrl: URL? = if lines[4].hasPrefix("SourceUrl:") , let value = toValue(lines[4], key: "SourceUrl:"), let url = URL(string: value), url.isValid {
        url
    } else { nil }
    
    let videoUrl: URL? = if lines[5].hasPrefix("VideoUrl:"), let value = toValue(lines[5], key: "VideoUrl:"), let url = URL(string: value), url.isValid {
        url
    } else { nil }
    
    guard let name else { continue }
    submissions.append(
        .init(
            name: name,
            status: status ?? .unknown,
            technologies: technologies,
            aboutMeUrl: aboutMeUrl,
            sourceUrl: sourceUrl,
            videoUrl: videoUrl
        )
    )
}

//AboutMeUrl
//SourceUrl
//VideoUrl

// MARK: - Generate new README.md file from template
var readmeFile: String {
"""
# WWDC \(year) - \(name)
![WWDC\(year) Logo](logo.png)

List of student submissions for the WWDC \(year) - \(name).

### How to add your submission?
1. [Click here](https://github.com/wwdc/\(year)/edit/master/Template.md) to fork this repository and edit the `Template.md` file.
2. Fill out the document based on the example in the comment below.
3. Make a new Pull Request and wait for the review.

#### How to update your submission?
If you would like to update your submission status please find your file in `Submission` directory. Edit file, update status and create Pull Request.

### Submissions

| Name | Source |    Video    | Technologies | Status |
|-----:|:------:|:-----------:|:-------------|:------:|
\(submissions.sorted(by: { $0.name < $1.name}).map(\.row).joined(separator: "\n"))

##### Total: \(submissions.count) | Accepted: \(submissions.filter { $0.status == .accepted }.count)
"""
}

print(readmeFile)
