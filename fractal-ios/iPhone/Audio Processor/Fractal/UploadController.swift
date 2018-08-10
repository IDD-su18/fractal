//
//import Foundation
//import Alamofire
//
//public class UploadController {
//    public typealias CompletionHandler = (_ obj:AnyObject?, _ success: Bool?) -> Void
//    
//    public func UploadWithAlamofire(filePath: NSURL, _ aHandler: CompletionHandler?) -> Void {
//        // Set Content-Type in HTTP header
//        let boundaryConstant = "Boundary-7MA4YWxkTLLu0UIW";
//        let contentType = "multipart/form-data; boundary=" + boundaryConstant
//        let accessTokenHeader = ""
//        
//        var fileData : NSData?
//        if let fileContents = FileManager.defaultManager().contentsAtPath(filePath.path!) {
//            fileData = fileContents
//        }
//        
//        let fileName = filePath.lastPathComponent
//        let mimeType = "text/csv"
//        let fieldName = "uploadFile"
//        
//        Alamofire.request(ListsRouter.Upload(fieldName: fieldName, fileName: fileName, mimeType: mimeType, fileContents: fileData!, boundaryConstant: boundaryConstant))
//            .responseJSON {(request, response, JSON, error) in
//                if let apiError = error {
//                    completionHandler?(obj: error, success: false)
//                } else {
//                    if let status = JSON?.valueForKey("Status") as? NSString {
//                        if (status == "OK") {
//                            aHandler?(obj: JSON, success: true)
//                        } else {
//                            aHandler?(obj: JSON, success: false)
//                        }
//                    }
//                }
//        }
//    }
//    
//    
//    public func UploadNative(filePath: NSURL, _ aHandler: CompletionHandler?) -> Void {
//        let url:NSURL? = NSURL(string: "http://testapi.example.com/testupload.php")
//        let cachePolicy = NSURLRequest.CachePolicy.ReloadIgnoringLocalCacheData
//        var request = NSMutableURLRequest(URL: url!, cachePolicy: cachePolicy, timeoutInterval: 2.0)
//        request.HTTPMethod = "POST"
//        
//        // Set Content-Type in HTTP header.
//        let boundaryConstant = "Boundary-7MA4YWxkTLLu0UIW"; // This should be auto-generated.
//        let contentType = "multipart/form-data; boundary=" + boundaryConstant
//        
//        let fileName = filePath.path!.lastPathComponent
//        let mimeType = "text/csv"
//        let fieldName = "uploadFile"
//        
//        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
//        
//        // Set data
//        var error: NSError?
//        var dataString = "--\(boundaryConstant)\r\n"
//        dataString += "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n"
//        dataString += "Content-Type: \(mimeType)\r\n\r\n"
//        dataString += String(contentsOfFile: filePath.path!, encoding: NSUTF8StringEncoding, error: &error)!
//        dataString += "\r\n"
//        dataString += "--\(boundaryConstant)--\r\n"
//        
//        println(dataString) // This would allow you to see what the dataString looks like.
//        
//        // Set the HTTPBody we'd like to submit
//        let requestBodyData = (dataString as NSString).dataUsingEncoding(NSUTF8StringEncoding)
//        request.HTTPBody = requestBodyData
//        
//        // Make an asynchronous call so as not to hold up other processes.
//        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue(), completionHandler: {(response, dataObject, error) in
//            if let apiError = error {
//                aHandler?(obj: error, success: false)
//            } else {
//                aHandler?(obj: dataObject, success: true)
//            }
//        })
//    }
//    
//}
//
//
//public enum Router:URLRequestConvertible {
//    public static let baseUrlString:String = "http://testapi.example.com"
//    case Upload(fieldName: String, fileName: String, mimeType: String, fileContents: NSData, boundaryConstant:String);
//    
//    var method: Alamofire.Method {
//        switch self {
//        case Upload:
//            return .POST
//        default:
//            return .GET
//        }
//    }
//    
//    var path: String {
//        switch self {
//        case Upload:
//            return "/testupload.php"
//        default:
//            return "/"
//        }
//    }
//    
//    public var URLRequest: NSURLRequest {
//        var URL: NSURL = NSURL(string: ListsRouter.baseUrlString)!
//        var mutableURLRequest = NSMutableURLRequest(URL: URL.URLByAppendingPathComponent(path))
//        mutableURLRequest.HTTPMethod = method.rawValue
//        
//        switch self {
//        case .Upload(let fieldName, let fileName, let mimeType, let fileContents, let boundaryConstant):
//            let contentType = "multipart/form-data; boundary=" + boundaryConstant
//            var error: NSError?
//            let boundaryStart = "--\(boundaryConstant)\r\n"
//            let boundaryEnd = "--\(boundaryConstant)--\r\n"
//            let contentDispositionString = "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n"
//            let contentTypeString = "Content-Type: \(mimeType)\r\n\r\n"
//            
//            // Prepare the HTTPBody for the request.
//            let requestBodyData : NSMutableData = NSMutableData()
//            requestBodyData.appendData(boundaryStart.dataUsingEncoding(NSUTF8StringEncoding)!)
//            requestBodyData.appendData(contentDispositionString.dataUsingEncoding(NSUTF8StringEncoding)!)
//            requestBodyData.appendData(contentTypeString.dataUsingEncoding(NSUTF8StringEncoding)!)
//            requestBodyData.appendData(fileContents)
//            requestBodyData.appendData("\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
//            requestBodyData.appendData(boundaryEnd.dataUsingEncoding(NSUTF8StringEncoding)!)
//            
//            mutableURLRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
//            mutableURLRequest.HTTPBody = requestBodyData
//            return Alamofire.ParameterEncoding.URL.encode(mutableURLRequest, parameters: nil).0
//            
//        default:
//            return mutableURLRequest
//        }
//    }
//}
