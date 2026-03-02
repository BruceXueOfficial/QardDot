import Speech
import AVFoundation
import SwiftUI
import Combine

class ChatSpeechManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var recognizedText: String = ""
    @Published var isRecording = false
    @Published var permissionGranted = false
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
    }
    
    /// 启动录音（包含权限检查）
    func startRecording() {
        if !permissionGranted {
            requestPermission()
            return
        }
        startRecordingInternal()
    }
    
    /// 正常停止录音
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()

        recognitionRequest = nil
        recognitionTask = nil
        DispatchQueue.main.async { self.isRecording = false }
    }
    
    /// 取消录音（清空数据，不发送）
    /// 用于“上滑取消”功能
    func cancelRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // 显式取消任务
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 在设置 isRecording = false 之前清空文本
        DispatchQueue.main.async {
            self.recognizedText = ""
            self.isRecording = false
        }
    }
    
    // MARK: - Internal Logic
    
    private func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.permissionGranted = (status == .authorized)
                if status == .authorized { self?.startRecordingInternal() }
            }
        }
        
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if !granted {
                    self?.permissionGranted = false
                }
            }
        }
    }
    
    private func startRecordingInternal() {
        guard !audioEngine.isRunning else { return }
        
        // 每次开始录音前，必须强制清空上一次的识别结果
        DispatchQueue.main.async { self.recognizedText = "" }
        
        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        // 配置识别任务
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                DispatchQueue.main.async { self?.recognizedText = result.bestTranscription.formattedString }
            }
            if error != nil {
                self?.stopRecording()
            }
        }
        
        // 监听音频输入
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
        DispatchQueue.main.async { self.isRecording = true }
    }
}
