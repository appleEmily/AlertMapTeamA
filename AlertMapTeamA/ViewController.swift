//
//  ViewController.swift
//  AlertMapTeamA
//
//  Created by Emily Nozaki on 2023/11/21.
//

import UIKit
import MapKit
import CoreLocation
import AVFoundation


class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    let locationManager = CLLocationManager()
    
    var routeSteps: [CLLocationCoordinate2D] = []
    var currentStepIndex = 0
    
    //動かすためにタイマー
    var simulationTimer: Timer?
    
    //動きをピンで表示するためのもの。
    var currentLocationAnnotation: MKPointAnnotation?
    
    // 甲府駅
    let startCoordinate = CLLocationCoordinate2D(latitude: 35.667, longitude: 138.569)
    // 近くの場所
    let endCoordinate = CLLocationCoordinate2D(latitude: 35.66839907403077, longitude: 138.5698015058478)
    
    //危険地点を登録しておく
    let alertCoordinate = CLLocationCoordinate2D(latitude: 35.668170044075985, longitude: 138.57070443965304)
    
    //音を鳴らすための準備
    var audioPlayer: AVAudioPlayer?

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //魔法だと思って書いてね
        mapView.delegate = self
        
        //位置情報許可アラート表示のためのメソッドを呼ぶよ
        requestLocationAccess()
        
        //今回は、試しに甲府駅に現在地が来るようにメソッドを呼ぶよ
        setInitialLocation()
        
        //現在地・目的地にピンを立てるよ
        setupCurrentLocationAnnotation()
        setupDestinationAnnotation()
        
    }
    
    //現在地のピンを表示するよ。
    func setupCurrentLocationAnnotation() {
        currentLocationAnnotation = MKPointAnnotation()
        currentLocationAnnotation?.coordinate = startCoordinate
        currentLocationAnnotation?.title = "現在地"
        if let annotation = currentLocationAnnotation {
            mapView.addAnnotation(annotation)
        }
    }
    
    //目的地にピンを立てるよ
    func setupDestinationAnnotation() {
        let destinationAnnotation = MKPointAnnotation()
        destinationAnnotation.coordinate = endCoordinate
        destinationAnnotation.title = "目的地"
        mapView.addAnnotation(destinationAnnotation)
    }
    
    //最初の位置を指定するよ。
    func setInitialLocation() {
        let region = MKCoordinateRegion(center: startCoordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: true)
    }
    
    // CLLocationManagerDelegateのメソッド
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            // 位置情報取得の許可が与えられたときの処理
        }
    }
    
    @IBAction func start() {
        fetchRoute(from: startCoordinate, to: endCoordinate)
    }
    
    //リセットボタンで最初に戻る。
    @IBAction func reset() {
        
        //動いている途中だとしたら止めるよ。
        simulationTimer?.invalidate()
        // 既存のピンを削除
        if let annotation = currentLocationAnnotation {
            mapView.removeAnnotation(annotation)
        }
        //以前までの記録をリセットする
        routeSteps = []
        currentStepIndex = 0
        
        //今回は、試しに甲府駅に現在地が来るようにメソッドを呼ぶよ
        setInitialLocation()
        
        //現在地にピンを立てるよ
        setupCurrentLocationAnnotation()
        
    }
    
    // MKMapViewDelegateメソッドをオーバーライドして、カスタムピンを設定
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        let identifier = "CustomPin"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }
        
        // 現在地と目的地のピンの色を設定
        if annotation.title == "現在地" {
            annotationView?.markerTintColor = .green
            
        }  else if annotation.title == "目的地" {
            
            annotationView?.markerTintColor = .red
            
        }
        
        return annotationView
    }
    
    func fetchRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .automobile // 車での移動
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] (response, error) in
            guard let strongSelf = self else { return }
            if let route = response?.routes.first {
                strongSelf.showRoute(route)
            }
        }
    }
    
    func showRoute(_ route: MKRoute) {
        mapView.addOverlay(route.polyline)
        mapView.setVisibleMapRect(route.polyline.boundingMapRect, animated: true)
        
        // 経路上のポイントをrouteStepsに追加
        let routePoints = route.polyline.points()
        let routePointCount = route.polyline.pointCount
        
        routeSteps = []
        
        for i in 0..<routePointCount {
            let point = routePoints[i]
            let pointCoordinate = point.coordinate
            routeSteps.append(pointCoordinate)
        }
        
        // 経路に沿って移動を開始
        startFollowingRoute()
    }
    
    
    func startFollowingRoute() {
        guard !routeSteps.isEmpty else { return }
        simulationTimer?.invalidate()
        simulationTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(followRouteStep), userInfo: nil, repeats: true)
    }
    
    @objc func followRouteStep() {
        if currentStepIndex < routeSteps.count {
            let stepCoordinate = routeSteps[currentStepIndex]
            currentLocationAnnotation?.coordinate = stepCoordinate
            mapView.setCenter(stepCoordinate, animated: true)

            // 特定の地点との距離を計算
            let distance = CLLocation(latitude: stepCoordinate.latitude, longitude: stepCoordinate.longitude).distance(from: CLLocation(latitude: alertCoordinate.latitude, longitude: alertCoordinate.longitude))

            // 特定の地点に近づいたらアラートを鳴らす
            if distance < 50 {
                
                playAlertSound()
            }

            print(distance)
            currentStepIndex += 1
        } else {
            simulationTimer?.invalidate()
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            
            //案内線の色
            renderer.strokeColor = UIColor(red: 100/255.0, green: 149/255.0, blue: 237/255.0, alpha: 1.0)
            
            renderer.lineWidth = 5.0
            return renderer
        }
        return MKOverlayRenderer()
    }
    
    func playAlertSound() {
        
        // 既に音声が再生されている場合は、再生を中断しない
               if audioPlayer?.isPlaying == true {
                   return
               }
               
               guard let soundURL = Bundle.main.url(forResource: "bird", withExtension: "mp3") else {
                   print("音声ファイルが見つかりません")
                   return
               }
               
               do {
                   // audioPlayerのインスタンスを再利用
                   audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                   
                   audioPlayer?.play()
               } catch {
                   print("音声ファイルの再生に失敗しました: \(error)")
               }
    }
    

    //位置情報許可依頼。
    func requestLocationAccess() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }
    
}

