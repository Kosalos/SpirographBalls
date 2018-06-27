import UIKit
import MetalKit

let kludgeAutoLayout:Bool = false
let scrnSz:[CGPoint] = [ CGPoint(x:768,y:1024), CGPoint(x:834,y:1112), CGPoint(x:1024,y:1366) ] // portrait
let scrnIndex = 2
let scrnLandscape:Bool = false

let numSpheres:Int = 4

var constantData = ConstantData()
var spheres:[Sphere] = []
var widgets:[Widget] = []
var ribbon = Ribbon()
var vc:ViewController!

class ViewController: UIViewController{
    var renderer: Renderer!
    var ribbonWidth:Float = 0.2
    var sphereAlpha:Float = 1
    var ribbonAlpha:Float = 1
    var drawStyle:Int = 0
    var xAxisOnly:Bool = false
    
    @IBOutlet var metalView: MTKView!
    @IBOutlet var clearButton: BorderedButton!
    @IBOutlet var resetButton: BorderedButton!
    @IBOutlet var styleButton: BorderedButton!
    @IBOutlet var skinButton: BorderedButton!
    @IBOutlet var xOnlyButton: BorderedButton!
    @IBOutlet var piButton: BorderedButton!
    @IBOutlet var background: Background!
    
    @IBAction func clearPressed(_ sender: BorderedButton) { ribbon.reset() }
    @IBAction func resetPressed(_ sender: BorderedButton) { reset() }

    func restart() {
        for w in widgets { w.setNeedsDisplay() }
        ribbon.reset()
    }

    @IBAction func xOnlyPressed(_ sender: BorderedButton) {
        xAxisOnly = !xAxisOnly
        if xAxisOnly {
            for i in 1 ... numSpheres { spheres[i].rotY = 0;  }
            restart()
        }
    }

    @IBAction func stylePressed(_ sender: BorderedButton) {
        drawStyle = 1 - drawStyle
        for i in 0 ... numSpheres { spheres[i].setDrawStyle(drawStyle) }
    }
    
    @IBAction func piPressed(_ sender: BorderedButton) {
        func harmonize(_ v:Float) -> Float { // intent is that rotations are increments of pi / 60
            if v == 0 { return 0 }
            let v1:Float = Float.pi / 60.0
            let v2 = Int(v1 * 100000)
            let v3 = Int(v  * 100000)
            let v4:Int = Int(v3 / v2) * v2
            let ans = Float(v4) / 100000.0
            return ans
        }
        
        for i in 1 ... numSpheres {
            spheres[i].rotX = harmonize(spheres[i].rotX)
            spheres[i].rotY = harmonize(spheres[i].rotY)
        }
        
        restart()
    }

    @IBAction func skinPressed(_ sender: BorderedButton) {
        tIndex1 = Int(arc4random() % 7)
        tIndex2 = Int(arc4random() % 7)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        vc = self
        
        metalView.device = MTLCreateSystemDefaultDevice()        
        renderer = Renderer(metalKitView: metalView)
        renderer.mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
        metalView.delegate = renderer
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        for i in 0 ... numSpheres {
            spheres.append(Sphere(i))
            if i > 0 { spheres[i].setRadius(0.7 - Float(i) * 0.1) }
        }
        
        for s in spheres { s.generate() }
        addWidgets()

        NotificationCenter.default.addObserver(self, selector: #selector(self.rotated), name: .UIDeviceOrientationDidChange, object: nil)
        Timer.scheduledTimer(withTimeInterval:0.02, repeats:true) { timer in self.update() }
        rotated()
        
        for w in widgets {
            view.addSubview(w)
            w.setNeedsDisplay()
        }
    }

    func reset() {
        ribbon.reset()
        for i in 1 ... numSpheres {
            spheres[i].reset()
            spheres[i].setRadius(0.7 - Float(i) * 0.1)
            for w in widgets { w.setNeedsDisplay() }
        }
    }
    
    //MARK: -

    func addWidgets() {
        let rRange:Float = 0.2
        var index = Int()

        func addWidget() {
            widgets.append(Widget())
            index = widgets.count - 1
        }

        for i in 0 ..< numSpheres {
            addWidget()
            widgets[index].initDual(&spheres[i+1].rotX, -rRange,rRange,rRange/10,String(format: "Rotate %d",i+1))
            widgets[index].initDual2(&spheres[i+1].rotY)
            
            addWidget()
            widgets[index].initSingle(&spheres[i+1].radius, 0.2,4.0,0.5,String(format: "Radius %d",i+1))
        }

        addWidget(); widgets[index].initSingle(&ribbonWidth, 0.01,0.9,0.1, "Ribbon Width")
        addWidget(); widgets[index].initSingle(&ribbonAlpha, 0.01,1,0.1,   "Ribbon alpha")
        addWidget(); widgets[index].initSingle(&sphereAlpha, 0.00,1,0.1,   "Sphere alpha")
        
        widgets[0].ident = 1
    }
    
    //MARK: -

    func update() {
        for s in spheres { s.update() }
        for w in widgets { _ = w.update() }
        
        // ribbon edge centered on last sphere, along a line that connects it to the previous sphere
        let base = spheres[numSpheres-1].center // 2nd to last sphere
        let end = spheres[numSpheres].center  // last sphere
        let diff = end - base
        let p1 = base + diff * (1.0 - ribbonWidth)
        let p2 = base + diff * (1.0 + ribbonWidth)
        ribbon.addStrip(p1,p2)
        
        rotateView()
    }
    
    //MARK: -

    var tIndex1:Int = 0  // random texture indices
    var tIndex2:Int = 2

    func render(_ renderEncoder:MTLRenderCommandEncoder) {
        
        if sphereAlpha > 0 {
            renderEncoder.setFragmentTexture(textures[tIndex1], index:0)
            for s in spheres { s.render(renderEncoder) }
        }
        
        renderEncoder.setFragmentTexture(textures[tIndex2], index:0)
        ribbon.render(renderEncoder) 
    }

    //MARK: -
    
    @objc func rotated() {
        var xs = view.bounds.width
        var ys = view.bounds.height
        if kludgeAutoLayout {
            xs = scrnLandscape ? scrnSz[scrnIndex].y : scrnSz[scrnIndex].x
            ys = scrnLandscape ? scrnSz[scrnIndex].x : scrnSz[scrnIndex].y
        }
        
        var x:CGFloat = 0
        var y:CGFloat = 0
        let bys:CGFloat = 35
        let gap:CGFloat = 5

        func frame(_ xs:CGFloat, _ ys:CGFloat, _ dx:CGFloat, _ dy:CGFloat) -> CGRect {
            let r = CGRect(x:x, y:y, width:xs, height:ys)
            x += dx; y += dy
            return r
        }

        if xs > ys {    // landscape
            let wxs:CGFloat = 110
            let gap2 = wxs + gap * 2
            let left = ys + 10
            let top:CGFloat = ys/2 - 260
            var index:Int = 0

            metalView.frame = CGRect(x:0, y:0, width:ys, height:ys)
            x = left
            y = top
            widgets[index].frame = frame(wxs,wxs,0,wxs+gap); index += 1 // rotate,radius 1
            widgets[index].frame = frame(wxs,bys,0,0); index += 1
            x += wxs + gap * 2
            y = top
            widgets[index].frame = frame(wxs,wxs,0,wxs+gap); index += 1 // rotate,radius 2
            widgets[index].frame = frame(wxs,bys,0,0); index += 1
            x = left
            y = top + wxs + bys + gap * 5
            let y2 = y
            widgets[index].frame = frame(wxs,wxs,0,wxs+gap); index += 1 // rotate,radius 3
            widgets[index].frame = frame(wxs,bys,0,0); index += 1
            x += gap2
            y = y2
            widgets[index].frame = frame(wxs,wxs,0,wxs+gap); index += 1 // rotate,radius 4
            widgets[index].frame = frame(wxs,bys,0,bys + gap * 5); index += 1
            x = left
            widgets[index].frame = frame(wxs,bys,gap2,0);    index += 1 // R width
            widgets[index].frame = frame(wxs,bys,0,bys+gap); index += 1 // R alpha
            x = left
            widgets[index].frame = frame(wxs,bys,gap2,0);    index += 1 // S alpha
            styleButton.frame = frame(wxs,bys,0,bys+gap)
            x = left
            clearButton.frame = frame(wxs,bys,gap2,0)
            skinButton.frame = frame(wxs,bys,0,bys+gap)
            x = left
            resetButton.frame = frame(wxs,bys,gap2,0)
            xOnlyButton.frame = frame(wxs/2,bys,wxs/2+5,0)
            piButton.frame = frame(wxs/2-5,bys,0,0)
        }
        else {      // portrait
            let wxs:CGFloat = 115
            let gap2 = wxs + gap * 2
            let left:CGFloat = xs/2 - 370
            let top:CGFloat = xs+10
            var index:Int = 0
            
            metalView.frame = CGRect(x:0, y:0, width:xs, height:xs)
            x = left
            y = top
            widgets[index].frame = frame(wxs,wxs,0,wxs+gap); index += 1 // rotate,radius 1
            widgets[index].frame = frame(wxs,bys,0,0); index += 1
            x += wxs + gap * 2
            y = top
            widgets[index].frame = frame(wxs,wxs,0,wxs+gap); index += 1 // rotate,radius 2
            widgets[index].frame = frame(wxs,bys,0,0); index += 1
            x += wxs + gap * 2
            y = top
            widgets[index].frame = frame(wxs,wxs,0,wxs+gap); index += 1 // rotate,radius 3
            widgets[index].frame = frame(wxs,bys,0,0); index += 1
            x += wxs + gap * 2
            y = top
            widgets[index].frame = frame(wxs,wxs,0,wxs+gap); index += 1 // rotate,radius 4
            widgets[index].frame = frame(wxs,bys,0,0); index += 1
            x += wxs + gap * 2
            let x2 = x
            y = top
            widgets[index].frame = frame(wxs,bys,gap2,0);    index += 1 // R width
            widgets[index].frame = frame(wxs,bys,0,bys+gap); index += 1 // R alpha
            x = x2
            widgets[index].frame = frame(wxs,bys,gap2,0);    index += 1 // S alpha
            styleButton.frame = frame(wxs,bys,0,bys+gap)
            x = x2
            clearButton.frame = frame(wxs,bys,gap2,0)
            skinButton.frame = frame(wxs,bys,0,bys+gap)
            x = x2
            resetButton.frame = frame(wxs,bys,gap2,0)
            xOnlyButton.frame = frame(wxs/2,bys,wxs/2+5,0)
            piButton.frame = frame(wxs/2-5,bys,0,0)
        }
        
        let hk = metalView.bounds
        arcBall.initialize(Float(hk.size.width),Float(hk.size.height))
        rotateCenter.x = hk.size.width/2
        rotateCenter.y = hk.size.height/2
        
        background.createGradientLayer()
    }
    
    //MARK: -
    
    var rotateCenter = CGPoint()
    var paceRotate = CGPoint()
    
    func rotateView() {
        arcBall.mouseDown(CGPoint(x: rotateCenter.x, y: rotateCenter.y))
        arcBall.mouseMove(CGPoint(x: rotateCenter.x - paceRotate.x, y: rotateCenter.y - paceRotate.y))
    }
    
    @IBAction func panGesture(_ sender: UIPanGestureRecognizer) {
        let pt = sender.translation(in: self.view)
        let scale:CGFloat = 0.1
        paceRotate.x = pt.x * scale
        paceRotate.y = pt.y * scale
    }
    
    var startZoom:Float = 0
    
    @IBAction func pinchGesture(_ sender: UIPinchGestureRecognizer) {
        let min:Float = 1
        let max:Float = 100
        if sender.state == .began { startZoom = translationAmount }
        translationAmount = startZoom / Float(sender.scale)
        if translationAmount < min { translationAmount = min }
        if translationAmount > max { translationAmount = max }
    }
    
    
    @IBAction func tapGesture(_ sender: UITapGestureRecognizer) {
        paceRotate.x = 0
        paceRotate.y = 0
    }

    override var prefersStatusBarHidden: Bool { return true }
}
