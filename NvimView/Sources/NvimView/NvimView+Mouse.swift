/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import RxNeovim
import RxSwift

public extension NvimView {
  override func mouseDown(with event: NSEvent) {
    self.mouse(event: event, vimName: "LeftMouse")
  }

  override func mouseUp(with event: NSEvent) {
    self.mouse(event: event, vimName: "LeftRelease")
  }

  override func mouseDragged(with event: NSEvent) {
    self.mouse(event: event, vimName: "LeftDrag")
  }

  override func rightMouseDown(with event: NSEvent) {
    self.mouse(event: event, vimName: "RightMouse")
  }

  override func rightMouseUp(with event: NSEvent) {
    self.mouse(event: event, vimName: "RightRelease")
  }

  override func rightMouseDragged(with event: NSEvent) {
    self.mouse(event: event, vimName: "RightDrag")
  }

  override func otherMouseUp(with event: NSEvent) {
    self.mouse(event: event, vimName: "MiddleMouse")
  }

  override func otherMouseDown(with event: NSEvent) {
    self.mouse(event: event, vimName: "MiddleRelease")
  }

  override func otherMouseDragged(with event: NSEvent) {
    self.mouse(event: event, vimName: "MiddleDrag")
  }

  override func scrollWheel(with event: NSEvent) {
    let (deltaX, deltaY) = (event.scrollingDeltaX, event.scrollingDeltaY)
    if deltaX == 0, deltaY == 0 { return }

    let cellPosition = self.cellPosition(forEvent: event)

    let isTrackpad = event.hasPreciseScrollingDeltas
    if isTrackpad == false {
      let (vimInputX, vimInputY) = self.vimScrollInputFor(
        deltaX: deltaX,
        deltaY: deltaY,
        modifierFlags: event.modifierFlags,
        cellPosition: cellPosition
      )
      self.api
        .input(keys: vimInputX, errWhenBlocked: false).asCompletable()
        .andThen(self.api.input(keys: vimInputY, errWhenBlocked: false).asCompletable())
        .subscribe(onError: { [weak self] error in
          self?.log.error("Error in \(#function): \(error)")
        })
        .disposed(by: self.disposeBag)

      return
    }

    if event.phase == .began {
      self.trackpadScrollDeltaX = 0
      self.trackpadScrollDeltaY = 0
    }

    self.trackpadScrollDeltaX += deltaX
    self.trackpadScrollDeltaY += deltaY
    let (deltaCellX, deltaCellY) = (
      (self.trackpadScrollDeltaX / self.cellSize.width).rounded(.toNearestOrEven),
      (self.trackpadScrollDeltaY / self.cellSize.height).rounded(.toNearestOrEven)
    )
    self.trackpadScrollDeltaX.formRemainder(dividingBy: self.cellSize.width)
    self.trackpadScrollDeltaY.formRemainder(dividingBy: self.cellSize.height)

    let (absDeltaX, absDeltaY) = (
      min(Int(abs(deltaCellX)), maxScrollDeltaX),
      min(Int(abs(deltaCellY)), maxScrollDeltaY)
    )
    var (horizSign, vertSign) = (deltaCellX > 0 ? 1 : -1, deltaCellY > 0 ? 1 : -1)
    if event.isDirectionInvertedFromDevice {
      vertSign = -vertSign
    }
    self.log
      .debug(
        "# scroll: \(cellPosition.row + vertSign * absDeltaY) \(cellPosition.column + horizSign * absDeltaX)"
      )

    self.api.winGetCursor(window: RxNeovimApi.Window(0))
      .map {
        guard $0.count == 2
        else {
          self.log.error("Error decoding \($0)")
          return
        }
        self.api.winSetCursor(
          window: RxNeovimApi.Window(0),
          pos: [$0[0] + vertSign * absDeltaY, $0[1] + horizSign * absDeltaX]
        )
        .subscribe(onError: { [weak self] error in
          self?.log.error("Error in \(#function): \(error)")
        })
        .disposed(by: self.disposeBag)
      }
      .subscribe(onFailure: { [weak self] error in
        self?.log.error("Error in \(#function): \(error)")
      })
      .disposed(by: self.disposeBag)
  }

  override func magnify(with event: NSEvent) {
    let factor = 1 + event.magnification
    let pinchTargetScale = self.pinchTargetScale * factor
    let resultingFontSize = round(pinchTargetScale * self.font.pointSize)
    if resultingFontSize >= NvimView.minFontSize, resultingFontSize <= NvimView.maxFontSize {
      self.pinchTargetScale = pinchTargetScale
    }

    switch event.phase {
    case .began:
      let pinchImageRep = self.bitmapImageRepForCachingDisplay(in: self.bounds)!
      self.cacheDisplay(in: self.bounds, to: pinchImageRep)
      self.pinchBitmap = pinchImageRep

      self.isCurrentlyPinching = true

    case .ended, .cancelled:
      self.isCurrentlyPinching = false
      self.updateFontMetaData(NSFontManager.shared.convert(self.font, toSize: resultingFontSize))
      self.pinchTargetScale = 1

    default:
      break
    }

    self.markForRenderWholeView()
  }

  internal func position(at location: CGPoint) -> Position {
    let row = Int((self.bounds.size.height - location.y - self.offset.y) / self.cellSize.height)
    let column = Int((location.x - self.offset.x) / self.cellSize.width)

    let position = Position(
      row: min(max(0, row), self.ugrid.size.height - 1),
      column: min(max(0, column), self.ugrid.size.width - 1)
    )
    return position
  }

  private func cellPosition(forEvent event: NSEvent) -> Position {
    let location = self.convert(event.locationInWindow, from: nil)
    return self.position(at: location)
  }

  private func mouse(event: NSEvent, vimName: String) {
    let cellPosition = self.cellPosition(forEvent: event)
    guard self.shouldFireVimInputFor(event: event, newCellPosition: cellPosition) else { return }

    let vimMouseLocation = self.wrapNamedKeys("\(cellPosition.column),\(cellPosition.row)")
    let vimClickCount = self.vimClickCountFrom(event: event)

    let result: String
    if let vimModifiers = self.vimModifierFlags(event.modifierFlags) {
      result = self.wrapNamedKeys("\(vimModifiers)\(vimClickCount)\(vimName)") + vimMouseLocation
    } else {
      result = self.wrapNamedKeys("\(vimClickCount)\(vimName)") + vimMouseLocation
    }

    self.api
      .input(keys: result, errWhenBlocked: false)
      .subscribe(onFailure: { [weak self] error in
        self?.log.error("Error in \(#function): \(error)")
      })
      .disposed(by: self.disposeBag)
  }

  private func shouldFireVimInputFor(event: NSEvent, newCellPosition: Position) -> Bool {
    let type = event.type
    guard type == .leftMouseDragged
      || type == .rightMouseDragged
      || type == .otherMouseDragged
    else {
      self.lastClickedCellPosition = newCellPosition
      return true
    }

    if self.lastClickedCellPosition == newCellPosition { return false }

    self.lastClickedCellPosition = newCellPosition
    return true
  }

  private func vimClickCountFrom(event: NSEvent) -> String {
    let clickCount = event.clickCount

    guard clickCount >= 2, clickCount <= 4 else { return "" }

    switch event.type {
    case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp: return "\(clickCount)-"
    default: return ""
    }
  }

  private func vimScrollEventNamesFor(deltaX: CGFloat, deltaY: CGFloat) -> (String, String) {
    let typeY: String
    if deltaY > 0 { typeY = "ScrollWheelUp" }
    else { typeY = "ScrollWheelDown" }

    let typeX: String
    if deltaX < 0 { typeX = "ScrollWheelRight" }
    else { typeX = "ScrollWheelLeft" }

    return (typeX, typeY)
  }

  private func vimScrollInputFor(
    deltaX: CGFloat, deltaY: CGFloat,
    modifierFlags: NSEvent.ModifierFlags,
    cellPosition: Position
  ) -> (String, String) {
    let vimMouseLocation = self.wrapNamedKeys("\(cellPosition.column),\(cellPosition.row)")

    let (typeX, typeY) = self.vimScrollEventNamesFor(deltaX: deltaX, deltaY: deltaY)
    let resultX: String
    let resultY: String
    if let vimModifiers = self.vimModifierFlags(modifierFlags) {
      resultX = self.wrapNamedKeys("\(vimModifiers)\(typeX)") + vimMouseLocation
      resultY = self.wrapNamedKeys("\(vimModifiers)\(typeY)") + vimMouseLocation
    } else {
      resultX = self.wrapNamedKeys("\(typeX)") + vimMouseLocation
      resultY = self.wrapNamedKeys("\(typeY)") + vimMouseLocation
    }

    return (resultX, resultY)
  }
}

private let maxScrollDeltaX = 15
private let maxScrollDeltaY = 15
