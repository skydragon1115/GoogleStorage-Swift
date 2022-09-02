//
//  ATGoogleDrive.swift
//  ATGoogleDriveDemo
//
//  Created by Dejan on 10/04/2018.
//  Copyright © 2018 Dejan. All rights reserved.
//

import Foundation
import GoogleAPIClientForREST

enum GDriveError: Error {
    case NoDataAtPath
}

class ATGoogleDrive {
    
    private let service: GTLRDriveService
    
    init(_ service: GTLRDriveService) {
        self.service = service
    }
    
    public func listFilesInFolder(_ folder: String, onCompleted: @escaping (GTLRDrive_FileList?, Error?) -> ()) {
        search(folder) { (folderID, error) in
            guard let ID = folderID else {
                onCompleted(nil, error)
                return
            }
            self.listFiles(ID, onCompleted: onCompleted)
        }
    }
    
    private func listFiles(_ folderID: String, onCompleted: @escaping (GTLRDrive_FileList?, Error?) -> ()) {
        let query = GTLRDriveQuery_FilesList.query()
            query.pageSize = 100
            query.q = "'\(folderID)' in parents and mimeType != 'application/vnd.google-apps.folder'"
            self.service.executeQuery(query) { (ticket, result, error) in
                onCompleted(result as? GTLRDrive_FileList, error)
            }
    }
    
//    public func listFiles(_ folderID: String, onCompleted: @escaping (GTLRDrive_FileList?, Error?) -> ()) {
//        let query = GTLRDriveQuery_FilesList.query()
//        query.pageSize = 100
//        query.q = "'\(folderID)' in parents and mimeType != 'application/vnd.google-apps.folder'"
//        self.service.executeQuery(query) { (ticket, result, error) in
//            onCompleted(result as? GTLRDrive_FileList, error)
//        }
//    }
    
    func upload(name: String, folderID: String, data: Data, mimeType: String, onCompleted: ((String?, Error?) -> ())?) {
        let file = GTLRDrive_File()
        file.name = name
        file.parents = [folderID]
        
        // Optionally, GTLRUploadParameters can also be created with a Data object.
//        let uploadParameters = GTLRUploadParameters(fileURL: fileURL, mimeType: mimeType)
        let uploadParameters = GTLRUploadParameters(data: data, mimeType: mimeType)
        uploadParameters.shouldUploadWithSingleRequest = true
            
        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: uploadParameters)
//        query.fields = "id"
        
        service.uploadProgressBlock = { _, totalBytesUploaded, totalBytesExpectedToUpload in
            // This block is called multiple times during upload and can
            // be used to update a progress indicator visible to the user.
            print (totalBytesUploaded, totalBytesExpectedToUpload)
        }
        
        service.executeQuery(query) { (ticket, result, error) in
            guard error == nil else {
                fatalError(error!.localizedDescription)
            }
            onCompleted?((result as? GTLRDrive_File)?.identifier, error)
        }
    }
    
    
    
    public func download(_ fileID: String, onCompleted: @escaping (Data?, Error?) -> ()) {
        let query = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: fileID)
        service.uploadProgressBlock = { _, totalBytesUploaded, totalBytesExpectedToUpload in
            print (totalBytesUploaded, totalBytesExpectedToUpload)
        }
        service.executeQuery(query) { (ticket, file, error) in
            guard error == nil else {
                fatalError(error!.localizedDescription)
            }
            onCompleted((file as? GTLRDataObject)?.data, error)
        }
    }
    
    
    
    
    public func search(_ fileName: String, onCompleted: @escaping (String?, Error?) -> ()) {
        let query = GTLRDriveQuery_FilesList.query()
        query.pageSize = 1
        query.q = "name contains '\(fileName)'"
        
        service.executeQuery(query) { (ticket, results, error) in
            onCompleted((results as? GTLRDrive_FileList)?.files?.first?.identifier, error)
        }
    }
    
    public func createFolder(_ name: String, onCompleted: @escaping (String?, Error?) -> ()) {
        let file = GTLRDrive_File()
        file.name = name
        file.mimeType = "application/vnd.google-apps.folder"
        
        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: nil)
        query.fields = "id"
        
        service.executeQuery(query) { (ticket, folder, error) in
            onCompleted((folder as? GTLRDrive_File)?.identifier, error)
        }
    }
    
    public func delete(_ fileID: String, onCompleted: ((Error?) -> ())?) {
        let query = GTLRDriveQuery_FilesDelete.query(withFileId: fileID)
        service.executeQuery(query) { (ticket, nilFile, error) in
            onCompleted?(error)
        }
    }
}
