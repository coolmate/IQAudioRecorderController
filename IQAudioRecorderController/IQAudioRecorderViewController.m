//
//  ViewController.swift
//  BarroLauncher
//
//  Created by David Liang on 11/09/2016.
//  Copyright © 2016 David Liang. All rights reserved.
//

import UIKit
import WebKit
import AVFoundation
import IQAudioRecorderController
import Alamofire
import Toaster
import AudioPlayer
import Whisper

class BarroViewController: UIViewController, IQAudioRecorderViewControllerDelegate, WKNavigationDelegate,WKScriptMessageHandler {
    
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func udocs_hide_navbar(){
        self.navigationController?.isNavigationBarHidden = true
    }
    
    func udocs_show_navbar(){
        self.navigationController?.isNavigationBarHidden = false
    }
    
    func udocs_toggle_navbar(){
        if(self.navigationController?.isNavigationBarHidden)!{
            self.udocs_show_navbar()
        }else{
            self.udocs_hide_navbar()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if(self.fullScreen){
            self.udocs_hide_navbar()
        }
        
    }

    var urlBase = "http://win.udocscloud.com:8899"
    var fullScreen = false

    func audioRecorderController(_ controller: IQAudioRecorderViewController, didFinishWithAudioAtPath filePath: String) {
        
        let audioFileURL = URL(fileURLWithPath: filePath)

        Alamofire.upload(
            
            multipartFormData: { multipartFormData in
                multipartFormData.append(audioFileURL, withName: "AudioFile")
                multipartFormData.append("106".data(using: String.Encoding.utf8)!, withName: "Sender")
            },
            
             to: "http://win.udocscloud.com:8899/GPS/locsvc/addVoiceMessageFile",
            encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.responseJSON { response in
 
                        if let result = response.result.value {
                            let JSON = result as! NSDictionary
                            let feedback = "\(JSON["Feedback"]!)"
                            
                            let toast = Toast(text: feedback)
                            toast.show()
                            
                            
                        }
                    }
                case .failure(let encodingError):
                    print("failed")
                    print(encodingError)
                }
            }
        )
        
        
        
        controller.dismiss(animated: true, completion: { _ in })
    }
    
    func audioRecorderControllerDidCancel(_ controller: IQAudioRecorderViewController) {
        //Notifying that user has clicked cancel.
        controller.dismiss(animated: true, completion: { _ in })
    }
    
    
	var webView: WKWebView?

    
    func createDirectory(){
        let fileManager = FileManager.default
        let paths = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString).appendingPathComponent("VoiceMessages")
        if !fileManager.fileExists(atPath: paths){
            try! fileManager.createDirectory(atPath: paths, withIntermediateDirectories: true, attributes: nil)
        }else{
            print("Already dictionary created.")
        }
    }
    
    func clearAllFilesFromTempDirectory(){
        
        let fileManager = FileManager.default
        
        do {
            
            let tmpFolderUrl = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("0D670D8B-F01E-43BA-BD95-A71991D029D8-1472-00000180DD5B2D80.m4a")
            
            try fileManager.removeItem(at: tmpFolderUrl)
            
            
            let allFiles = try fileManager.contentsOfDirectory(atPath: tmpFolderUrl.absoluteString)
            
            for aFile in allFiles {
                try fileManager.removeItem(at: URL(fileURLWithPath: aFile))
            }
        }
        catch let error as NSError {
            print("Ooops! Something went wrong: \(error)")
        }
    }
    
	required init(coder aDecoder: NSCoder) {
        
        self.webView = WKWebView(
            frame: CGRect.zero
            
        )

        voiceMsgPlayQueue = [""]
		super.init(coder: aDecoder)!
	}

    
	@IBOutlet var containerView: UIView!

    
    
    private func webView(webView: WKWebView, didReceiveAuthenticationChallenge challenge: URLAuthenticationChallenge,
                 completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let cred = URLCredential.init(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, cred)
    }
    
     let audioPlayer = try!AudioPlayer(fileName:"arpeggio.mp3")
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if(message.name == "callbackHandler") {
            //print("JavaScript is sending a message \(message.body)")
            
            let actionRequest = "\(message.body)"
            
            let actionRequestAry = actionRequest.components(separatedBy: "|")
            
            let actionName = actionRequestAry[0]
            
            switch actionName {
            case "StartRecording":
                triggerVoicRecord()
                
            case "NewMsgArrivedAlert":
                self.audioPlayer.play()
                break
            case "PlayVoiceMsg":
                let voiceFileNames = actionRequestAry[1]
                
                if(!voiceFileNames.isEmpty)
                {
                    let voiceFilesAry = voiceFileNames.components(separatedBy: ",")
                    
                    
                    for voiceFile in voiceFilesAry{
                        self.playMsg(voiceFile: voiceFile)
                    }
                    /*
                    self.voiceMsgPlayQueue.append(contentsOf: voiceFilesAry)
                    
                    if(!self.isPlayingVoiceMsg){
                        startPlayingVoiceMsg()
                    }
                    */
                }
            case "PrintPDF":
                let pdfUrl = "\(urlBase)/countersolution/\(actionRequestAry[1])"
                
                if let url = NSURL(string: pdfUrl) {
                    if (UIPrintInteractionController.canPrint(url as URL)) {
                        showPrintInteraction(url: url)
                    } else {
                        
                    }
                }
            case "PrintLabelTestingLabel":
                let paramsAry = actionRequestAry[1].components(separatedBy: ",")
                
                let printerIp = paramsAry[0]
                let jobNumber = paramsAry[1]
                let mix = paramsAry[2]
                let strength = paramsAry[3]
                let agg = paramsAry[4]
                let slump = paramsAry[5]
                let docket = paramsAry[6]
                self.printLabelTestingLabel(printerIp: printerIp, jobNumber: jobNumber, mix: mix, strength: strength, agg: agg, slump: slump, docket: docket)
                
            case "PrintLabelProgressiveLabel":
                let paramsAry = actionRequestAry[1].components(separatedBy: ",")
                
                let printerIp = paramsAry[0]
                let jobNumber = paramsAry[1]
                let customer = paramsAry[2]
                let qtyDel = paramsAry[3]
                let progTotal = paramsAry[4]
                let docket = paramsAry[5]
                self.printLabelProgressvieLabel(printerIp: printerIp, jobNumber: jobNumber, customer: customer, qtyDel: qtyDel, progTotal: progTotal, docket: docket)
                
            case "PrintLabelCODLabel":
                let paramsAry = actionRequestAry[1].components(separatedBy: ",")
                
                let printerIp = paramsAry[0]
                let jobNumber = paramsAry[1]
                let customer = paramsAry[2]
                let account = paramsAry[3]
                let amountDue = paramsAry[4]
                let docket = paramsAry[5]
                self.printLabelCODLabel(printerIp: printerIp, jobNumber: jobNumber, customer: customer, account: account, amountDue: amountDue, docket: docket)
                
                
            default:
                triggerVoicRecord()
            }
        }
    }
    
    
    
    func showPrintInteraction(url: NSURL) {
        if let controller:UIPrintInteractionController = UIPrintInteractionController.shared {
            controller.printingItem = url
            controller.printInfo = printerInfo(jobName: url.lastPathComponent!)
            controller.present(animated: true, completionHandler: nil)
        }
    }
    
    func printerInfo(jobName: String) -> UIPrintInfo {
        let printInfo = UIPrintInfo.printInfo()
        printInfo.outputType = .general
        printInfo.jobName = jobName
        return printInfo
    }
    
    var voiceMsgPlayQueue : [String]
    var avPlayer: AVPlayer!
    var currentVoiceMsgIdx = 0
    var isPlayingVoiceMsg = false

    
    func startPlayingVoiceMsg(){
        let voiceFile = self.voiceMsgPlayQueue[self.currentVoiceMsgIdx]
        self.playMsg(voiceFile: voiceFile)
    }
    
    
    func playMsg(voiceFile:String){
        
        let voiceUrl = "\(self.urlBase)/GPS/sound_clips/\(voiceFile)"
        
        let url = URL(string: voiceUrl)
        avPlayer = AVPlayer(url: url!)
        avPlayer.actionAtItemEnd = .none
        
        let asset = AVURLAsset(url: url!, options: nil)
        let audioDuration = asset.duration
        let audioDurationSeconds = CMTimeGetSeconds(audioDuration)
        
        
        let murmur = Murmur(title: "This is a small whistle...")
      
 
        
        // Hide a message
        hide(whistleAfter: 3)
        
        
        //self.view.makeToast("Playing voice message ...", duration: audioDurationSeconds, position: CSToastPositionBottom)
        
        let toast = Toast(text: "Playing voice message ...")
        toast.show()
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerItemDidReachEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem)
        avPlayer.play()
        
        
    }
    
    func playerItemDidReachEnd(_ notification: Notification) {
       /*
        let nextIdx = self.currentVoiceMsgIdx+1
        
        if(nextIdx == self.voiceMsgPlayQueue.count){
            return
        }
        
        self.currentVoiceMsgIdx = nextIdx
        
        self.startPlayingVoiceMsg()
         */
        
        
    }

    
    
    
	override func viewDidLoad() {
		super.viewDidLoad()
        
       
        
        
        
        //--# Below line is to enable the alarm to be played with sound although user has muted the phone.
        try!AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        
        
        let contentController = WKUserContentController();
        contentController.add(
            self as WKScriptMessageHandler,
            name: "callbackHandler"
        )
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        
        self.webView = WKWebView(
            frame: CGRect.zero,
            configuration: config
        )
        
        
        
        

        self.webView?.navigationDelegate = self
        
        createDirectory();
        
		self.containerView.addSubview(webView!)
        
		self.webView?.translatesAutoresizingMaskIntoConstraints = false
		let height = NSLayoutConstraint(item: webView!, attribute: .height, relatedBy: .equal, toItem: containerView, attribute: .height, multiplier: 1, constant: 0)
		let width = NSLayoutConstraint(item: webView!, attribute: .width, relatedBy: .equal, toItem: containerView, attribute: .width, multiplier: 1, constant: 0)
		view.addConstraints([height, width])

        self.webView?.scrollView.isScrollEnabled = false
        
        let url = URL(string: "\(self.urlBase)")
        
        let toast = Toast(text: "\(self.urlBase)")
        toast.show()
        
		let request = URLRequest(url: url! )
        

		self.webView!.load(request)
        
        
         self.addTwoFingerSwipeGesture()

		/*
        let btnVoice = UIButton (frame: CGRect(x: 0, y: 0, width: 50, height: 50))
		btnVoice.setTitle("M", for: UIControlState())
        btnVoice.backgroundColor = UIColor.black
		self.webView?.addSubview(btnVoice)

        btnVoice.addTarget(self, action: #selector(self.onVoiceTouchUpInside), for: UIControlEvents.touchUpInside)
         */
        
       
	}

    
    func addTwoFingerSwipeGesture() {
        let gesture = UISwipeGestureRecognizer(target: self, action: "handleTwoFingerSwipe")
        gesture.direction = .left
        gesture.numberOfTouchesRequired = 2 // 2 finger swipe
        self.webView?.scrollView.addGestureRecognizer(gesture)
    }
    
    func handleTwoFingerSwipe() {
        print("2 finger swipe recognized")
        self.udocs_toggle_navbar()
    }
    
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    

    func triggerVoicRecord(){
        let recordController : IQAudioRecorderViewController = IQAudioRecorderViewController()
        recordController.delegate = self
        recordController.title = "Record voice message, when finished press [Done] to send to the Barro HQ."
        recordController.maximumRecordDuration = -1
        recordController.allowCropping = true
        recordController.barStyle = .black
        recordController.sampleRate = CGFloat(16000.0)
        recordController.audioFormat = IQAudioFormat._m4a
        
        
        self.presentBlurredAudioRecorderViewControllerAnimated(recordController)

    }
    
    func onVoiceTouchUpInside(){
        clearAllFilesFromTempDirectory()
        
       triggerVoicRecord()
    }
    
    
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
    
    
    
    
    //--# COD Label
    func printLabelCODLabel(
        printerIp:String,
        jobNumber:String,
        customer:String,
        account:String,
        amountDue:String,
        docket:String
        ){
        
        var labelView: LabelCODLabelView?
        
        let viewArray = Bundle.main.loadNibNamed("LabelCODLabel", owner: self, options: nil)
        
        for _view in viewArray! {
            if  _view is LabelCODLabelView{
                labelView = _view as? LabelCODLabelView;
                break;
            }
        }
        
        if(labelView == nil){
            return;
        }
        
        labelView?.customer.text = customer
        labelView?.account.text = account
        labelView?.job.text = jobNumber
        labelView?.amountDue.text = amountDue
        labelView?.invDocket.text = docket
        
        let date = Date()
        let formatterDate = DateFormatter()
        formatterDate.dateFormat = "dd/MM/yyyy"
        
        
        labelView?.my_date.text = formatterDate.string(from: date)
        
        let formatterTime = DateFormatter()
        formatterTime.dateFormat = "hh:mm a."
        labelView?.my_time.text = formatterTime.string(from: date)
        
        
        
        
        let printInfo = BRPtouchPrintInfo()
        //
        printInfo.strPaperName = "62mm x 100mm"; //"62mm x 100mm";
        printInfo.nPrintMode = PRINT_FIT;
        printInfo.nDensity = 0;
        printInfo.nOrientation = ORI_PORTRATE;
        printInfo.nHalftone = HALFTONE_BINARY;
        printInfo.nHorizontalAlign = ALIGN_LEFT;
        printInfo.nVerticalAlign = ALIGN_TOP;
        printInfo.nPaperAlign = PAPERALIGN_LEFT;
        printInfo.nAutoCutFlag = 1;
        printInfo.nAutoCutCopies = 1;
        
        //
        
        
        let ptp = BRPtouchPrinter(printerName: "Brother QL-720NW")
        ptp?.setIPAddress(printerIp)
        
        
        ptp?.setPrintInfo(printInfo)
        
        let _labView = labelView!
        let imgRef = _labView.toLargeImage().cgImage
        
        let res = ptp?.print(imgRef, copy: 1, timeout: 500)
        print( String(format: "print res = %d", res!))
    }

    
    
    //--# ProgressiveLabel
    func printLabelProgressvieLabel(
        printerIp:String,
        jobNumber:String,
        customer:String,
        qtyDel:String,
        progTotal:String,
        docket:String
        ){
        
        var labelView: LabelProgressiveLabelView?
        
        let viewArray = Bundle.main.loadNibNamed("LabelProgressiveLabel", owner: self, options: nil)
        
        for _view in viewArray! {
            if  _view is LabelProgressiveLabelView{
                labelView = _view as? LabelProgressiveLabelView;
                break;
            }
        }
        
        if(labelView == nil){
            return;
        }
        
        labelView?.customer.text = customer
        labelView?.qty_del.text = qtyDel
        labelView?.job.text = jobNumber
        labelView?.prog_total.text = progTotal
        labelView?.invDocket.text = docket
        
        let date = Date()
        let formatterDate = DateFormatter()
        formatterDate.dateFormat = "dd/MM/yyyy"
        
        
        labelView?.my_date.text = formatterDate.string(from: date)
        
        let formatterTime = DateFormatter()
        formatterTime.dateFormat = "hh:mm a."
        labelView?.my_time.text = formatterTime.string(from: date)
        
        
        
        
        let printInfo = BRPtouchPrintInfo()
        //
        printInfo.strPaperName = "62mm x 100mm"; //"62mm x 100mm";
        printInfo.nPrintMode = PRINT_FIT;
        printInfo.nDensity = 0;
        printInfo.nOrientation = ORI_PORTRATE;
        printInfo.nHalftone = HALFTONE_BINARY;
        printInfo.nHorizontalAlign = ALIGN_LEFT;
        printInfo.nVerticalAlign = ALIGN_TOP;
        printInfo.nPaperAlign = PAPERALIGN_LEFT;
        printInfo.nAutoCutFlag = 1;
        printInfo.nAutoCutCopies = 1;
        
        //
        
        
        let ptp = BRPtouchPrinter(printerName: "Brother QL-720NW")
        ptp?.setIPAddress(printerIp)
        
        
        ptp?.setPrintInfo(printInfo)
        
        let _labView = labelView!
        let imgRef = _labView.toLargeImage().cgImage
        
        let res = ptp?.print(imgRef, copy: 1, timeout: 500)
        print( String(format: "print res = %d", res!))
    }

    
    //---# testing slip
    func printLabelTestingLabel(
        printerIp:String,
        jobNumber:String,
        mix:String,
        strength:String,
        agg:String,
        slump:String,
        docket:String
        ){
    
        var labelView: LabelTestingLabelView?
        
        let viewArray = Bundle.main.loadNibNamed("LabelTestingLabel", owner: self, options: nil)
        
        for _view in viewArray! {
            if  _view is LabelTestingLabelView{
                labelView = _view as? LabelTestingLabelView;
                break;
            }
        }
        
        if(labelView == nil){
            return;
        }
        
        labelView?.mix.text = mix
        labelView?.agg.text = agg
        labelView?.job.text = jobNumber
        labelView?.strength.text = strength
        labelView?.slump.text = slump
        labelView?.invDocket.text = docket
        
        let date = Date()
        let formatterDate = DateFormatter()
        formatterDate.dateFormat = "dd/MM/yyyy"
        
        
        labelView?.my_date.text = formatterDate.string(from: date)
        
        let formatterTime = DateFormatter()
        formatterTime.dateFormat = "hh:mm a."
        labelView?.my_time.text = formatterTime.string(from: date)
        
        
        
        
        let printInfo = BRPtouchPrintInfo()
        //
        printInfo.strPaperName = "62mm x 100mm"; //"62mm x 100mm";
        printInfo.nPrintMode = PRINT_FIT;
        printInfo.nDensity = 0;
        printInfo.nOrientation = ORI_PORTRATE;
        printInfo.nHalftone = HALFTONE_BINARY;
        printInfo.nHorizontalAlign = ALIGN_LEFT;
        printInfo.nVerticalAlign = ALIGN_TOP;
        printInfo.nPaperAlign = PAPERALIGN_LEFT;
        printInfo.nAutoCutFlag = 1;
        printInfo.nAutoCutCopies = 1;
        
        //
        
        
        let ptp = BRPtouchPrinter(printerName: "Brother QL-720NW")
        ptp?.setIPAddress(printerIp)
  
        ptp?.setPrintInfo(printInfo)
        
        let _labView = labelView!
        let imgRef = _labView.toLargeImage().cgImage
        
        let res = ptp?.print(imgRef, copy: 1, timeout: 500)
        print( String(format: "print res = %d", res!))
    }

}

