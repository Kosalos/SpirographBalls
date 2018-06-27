import UIKit

class Background: UIView {
    let gg:CGFloat = 0.2
    let hh:CGFloat = 0.0
    let gradientLayer = CAGradientLayer()
    var alreadyAddedGradient:Bool = false

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        if kludgeAutoLayout {
            let xs = scrnLandscape ? scrnSz[scrnIndex].y : scrnSz[scrnIndex].x
            let ys = scrnLandscape ? scrnSz[scrnIndex].x : scrnSz[scrnIndex].y

            UIColor(red:gg, green:gg, blue:gg, alpha: 1).setFill()
            UIBezierPath(rect:CGRect(x:0, y:0, width:xs, height:ys)).fill()
        }
    }
    
    func createGradientLayer() {
        let c1 = UIColor(red:gg, green:gg, blue:gg, alpha:1).cgColor
        let c2 = UIColor(red:hh, green:hh, blue:hh, alpha:1).cgColor
        
        if alreadyAddedGradient { gradientLayer.removeFromSuperlayer() }
        
        gradientLayer.frame = bounds
        gradientLayer.colors = [c2,c1]
        gradientLayer.startPoint = CGPoint(x:0, y:0)
        gradientLayer.endPoint = CGPoint(x:1, y:1)
        
        layer.insertSublayer(gradientLayer, at: 0)
        alreadyAddedGradient = true
    }
}
