//
//  ViewController.swift
//  ATGoogleDriveDemo
//
//  Created by Dejan on 09/04/2018.
//  Copyright © 2018 Dejan. All rights reserved.
//

import UIKit
import GoogleSignIn
import GoogleAPIClientForREST

class ViewController: UIViewController {

    @IBOutlet weak var resultsLabel: UILabel!
    
    let googleDriveService = GTLRDriveService()
    private var googleDrive: ATGoogleDrive?
    var googleUser: GIDGoogleUser?
    var uploadFolderID: String?
    var fileID: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupGoogleSignIn()
        
        googleDrive = ATGoogleDrive(googleDriveService)
        let button = GIDSignInButton()
        button.frame = CGRect(x: 100, y: 100, width: 300, height: 100)
        view.addSubview(button)
    }
    
    private func setupGoogleSignIn() {
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().scopes = [kGTLRAuthScopeDriveFile]
//        GIDSignIn.sharedInstance().signInSilently()
        
        GIDSignIn.sharedInstance().signIn()
    }
    
    func populateFolderID() {
        if (googleUser == nil) {
            return
        }
        
        let myFolderName = "GoogleTest"
        getFolderID(
            name: myFolderName,
            service: googleDriveService,
            user: googleUser!) { folderID in
            if folderID == nil {
                self.createFolder(
                    name: myFolderName,
                    service: self.googleDriveService) {
                    self.uploadFolderID = $0
                }
            } else {
                // Folder already exists
                self.uploadFolderID = folderID
            }
        }
    }
    
    // MARK: - Actions
    @IBAction func uploadAction(_ sender: Any) {
        let image = UIImage(named: "image.png")
        if let data = image?.jpegData(compressionQuality: 1.0) {
            googleDrive?.upload(name: "test", folderID: self.uploadFolderID!, data: data, mimeType: "image/png", onCompleted: { (fileID, error) in
                print("Upload file ID: \(fileID); Error: \(error?.localizedDescription)")
            })
        }
    }
    
    @IBAction func listAction(_ sender: Any) {
//        googleDrive?.listFilesInFolder("1VrnqKPz9SkUKVkbaCGR_M33RFti57NRf") { (files, error) in
//            guard let fileList = files else {
//                print("Error listing files: \(error?.localizedDescription)")
//                return
//            }
//
//            self.resultsLabel.text = fileList.files?.description
//        }
//
        googleDrive?.download("1ejDLaeB0iV18gLNNSa4lSdy9xblmgZ3s", onCompleted: { data, error in
            let fileManager = FileManager.default
            let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let targetURL = tempDirectoryURL.appendingPathComponent("test.png")
            if (fileManager.fileExists(atPath: targetURL.path)) {
                do {
                    try fileManager.removeItem(at: targetURL)
                } catch {
                }
            }
            
            do {
                try data!.write(to: targetURL)
                print (targetURL.absoluteString)
            } catch {
            }
        })
    }
    
    func getFolderID(
        name: String,
        service: GTLRDriveService,
        user: GIDGoogleUser,
        completion: @escaping (String?) -> Void) {
        
        let query = GTLRDriveQuery_FilesList.query()

        // Comma-separated list of areas the search applies to. E.g., appDataFolder, photos, drive.
        query.spaces = "drive"
        
        // Comma-separated list of access levels to search in. Some possible values are "user,allTeamDrives" or "user"
        query.corpora = "user"
            
        let withName = "name = '\(name)'" // Case insensitive!
        let foldersOnly = "mimeType = 'application/vnd.google-apps.folder'"
        let ownedByUser = "'\(user.profile!.email!)' in owners"
        query.q = "\(withName) and \(foldersOnly) and \(ownedByUser)"
        
        service.executeQuery(query) { (_, result, error) in
            guard error == nil else {
                fatalError(error!.localizedDescription)
            }
                                     
            let folderList = result as! GTLRDrive_FileList

            // For brevity, assumes only one folder is returned.
            completion(folderList.files?.first?.identifier)
        }
    }
    
    func createFolder(
        name: String,
        service: GTLRDriveService,
        completion: @escaping (String) -> Void) {
        
        let folder = GTLRDrive_File()
        folder.mimeType = "application/vnd.google-apps.folder"
        folder.name = name
        
        // Google Drive folders are files with a special MIME-type.
        let query = GTLRDriveQuery_FilesCreate.query(withObject: folder, uploadParameters: nil)
        
        service.executeQuery(query) { (_, file, error) in
            guard error == nil else {
                fatalError(error!.localizedDescription)
            }
            
            let folder = file as! GTLRDrive_File
            completion(folder.identifier!)
        }
    }
}

// MARK: - GIDSignInDelegate
extension ViewController: GIDSignInDelegate {
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if error == nil {
            self.googleDriveService.authorizer = user.authentication.fetcherAuthorizer()
            self.googleUser = user
            self.populateFolderID()
        } else {
            self.googleDriveService.authorizer = nil
            self.googleUser = nil
        }
    }
}

// MARK: - GIDSignInUIDelegate
extension ViewController: GIDSignInUIDelegate {}
