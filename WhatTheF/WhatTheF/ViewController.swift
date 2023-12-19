//
//  ViewController.swift
//  WhatTheF
//
//  Created by Terry Jason on 2023/12/18.
//

import UIKit
import CoreML
import Vision
import Alamofire
import SwiftyJSON
import SDWebImage

class ViewController: UIViewController {
    
    let imagePicker = UIImagePickerController()
    let wikipediaURl = "https://en.wikipedia.org/w/api.php"
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.allowsEditing = true
        
        textView.text = ""
        
        let textAttributes = [NSAttributedString.Key.foregroundColor:UIColor.white]
        navigationController?.navigationBar.titleTextAttributes = textAttributes
    }
    
    @IBAction func cameraTapped(_ sender: UIBarButtonItem) {
        self.present(imagePicker, animated: true)
    }
    
}

// MARK: - Detect Photo

extension ViewController {
    
    private func detectPhoto(of image: CIImage) {
        
        guard let model = try? VNCoreMLModel(for: FlowerClassifier(configuration: .init()).model) else {
            fatalError("Loading CoreML Model Failed")
        }
        
        let request = VNCoreMLRequest(model: model) { [self] request, error in
            guard error == nil else { return }
            
            guard let firstResult = request.results?.first as? VNClassificationObservation else { return }
            
            let name = firstResult.identifier.capitalized
            self.navigationItem.title = name
            afRequest(nameOf: name)
        }
        
        let handler = VNImageRequestHandler(ciImage: image)
        
        do {
            try handler.perform([request])
        } catch {
            print(error)
        }
        
    }
    
}

// MARK: - Alamofire HTTP Request

extension ViewController {
    
    private func afRequest(nameOf flowerName: String) {
        let parameters : [String:String] = [
            "format" : "json",
            "action" : "query",
            "prop" : "extracts|pageimages",
            "exintro" : "",
            "explaintext" : "",
            "titles" : flowerName,
            "indexpageids" : "",
            "redirects" : "1",
            "pithumbsize" : "500"
        ]
        
        AF.request(wikipediaURl, method: .get, parameters: parameters).responseData { self.resultHandler($0) }
    }
    
    private func resultHandler(_ res: AFDataResponse<Data>) {
        switch res.result {
        case .success(let data):
            do {
                let json = try JSON(data: data)
                getInfo(json)
            } catch {
                print("將數據轉換為 JSON 格式失敗 \(error.localizedDescription)")
            }
        case .failure(let failure):
            print("response 出現錯誤 \(failure)")
        }
    }
    
    private func getInfo(_ json: JSON) {
        guard let id = json["query"]["pageids"][0].string else { fatalError("JSON 型態轉換出錯") }
        
        let item = json["query"]["pages"][id]["extract"].stringValue
        let pageImageStringURL = json["query"]["pages"][id]["thumbnail"]["source"].stringValue
        
        imageView.sd_setImage(with: URL(string: pageImageStringURL))
        textView.text = item
    }
    
}

// MARK: - UIImagePickerControllerDelegate

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        guard let pickedImage = info[.originalImage] as? UIImage else { return }
        
        imageView.image = pickedImage
        
        guard let ciimage = CIImage(image: pickedImage) else { fatalError("Can't convert to CIImage") }
        detectPhoto(of: ciimage)
        
        Task { @MainActor in
            self.imagePicker.dismiss(animated: true)
        }
        
    }
    
}
