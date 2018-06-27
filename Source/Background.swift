import UIKit

class Background: UIView {

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        if kludgeAutoLayout {
            let xs = scrnLandscape ? scrnSz[scrnIndex].y : scrnSz[scrnIndex].x
            let ys = scrnLandscape ? scrnSz[scrnIndex].x : scrnSz[scrnIndex].y

            let gg:CGFloat = 0.2
            UIColor(red:gg, green:gg, blue:gg, alpha: 1).setFill()
            UIBezierPath(rect:CGRect(x:0, y:0, width:xs, height:ys)).fill()
        }
    }

}
