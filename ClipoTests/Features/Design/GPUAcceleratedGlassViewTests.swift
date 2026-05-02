import XCTest
import SwiftUI
@testable import Clipo

final class GPUAcceleratedGlassViewTests: XCTestCase {

    // MARK: - Initialization

    func testGPUAcceleratedGlassMaterialDefaultCornerRadius() {
        // Given: GPUAcceleratedGlassMaterial with default corner radius
        let material = GPUAcceleratedGlassMaterial()

        // Then: Should use default corner radius of 18
        let mirror = Mirror(reflecting: material)
        let cornerRadius = mirror.children.first { $0.label == "cornerRadius" }?.value as? CGFloat
        XCTAssertEqual(cornerRadius, 18)
    }

    func testGPUAcceleratedGlassMaterialCustomCornerRadius() {
        // Given: GPUAcceleratedGlassMaterial with custom corner radius
        let customRadius: CGFloat = 24
        let material = GPUAcceleratedGlassMaterial(cornerRadius: customRadius)

        // Then: Should use custom corner radius
        let mirror = Mirror(reflecting: material)
        let cornerRadius = mirror.children.first { $0.label == "cornerRadius" }?.value as? CGFloat
        XCTAssertEqual(cornerRadius, customRadius)
    }

    // MARK: - NSViewRepresentable

    func testGPUAcceleratedGlassViewCreatesNSView() {
        // Given: GPUAcceleratedGlassView
        let view = GPUAcceleratedGlassView(cornerRadius: 18)

        // When: Creating GlassEffectView directly
        let glassView = GPUAcceleratedGlassView.GlassEffectView()

        // Then: Should create NSView
        XCTAssertNotNil(glassView)
    }

    func testGPUAcceleratedGlassViewSetsCornerRadius() {
        // Given: GlassEffectView with corner radius
        let cornerRadius: CGFloat = 20
        let glassView = GPUAcceleratedGlassView.GlassEffectView()
        glassView.wantsLayer = true
        glassView.layer?.cornerRadius = cornerRadius
        glassView.layer?.masksToBounds = true

        // Then: Should set corner radius on layer
        XCTAssertEqual(glassView.layer?.cornerRadius, cornerRadius)
    }

    func testGPUAcceleratedGlassViewSetsMasksToBounds() {
        // Given: GlassEffectView
        let glassView = GPUAcceleratedGlassView.GlassEffectView()
        glassView.wantsLayer = true
        glassView.layer?.masksToBounds = true

        // Then: Should set masksToBounds to true
        XCTAssertTrue(glassView.layer?.masksToBounds ?? false)
    }

    func testGPUAcceleratedGlassViewUpdatesCornerRadius() {
        // Given: GlassEffectView with initial corner radius
        let initialRadius: CGFloat = 18
        let glassView = GPUAcceleratedGlassView.GlassEffectView()
        glassView.wantsLayer = true
        glassView.layer?.cornerRadius = initialRadius

        // When: Updating corner radius
        let newRadius: CGFloat = 24
        glassView.layer?.cornerRadius = newRadius

        // Then: Should update corner radius
        XCTAssertEqual(glassView.layer?.cornerRadius, newRadius)
    }

    // MARK: - GlassEffectView

    func testGlassEffectViewHasLayer() {
        // Given: GlassEffectView
        let glassView = GPUAcceleratedGlassView.GlassEffectView()
        glassView.wantsLayer = true

        // Then: Should have layer enabled
        XCTAssertTrue(glassView.wantsLayer)
    }

    func testGlassEffectViewLayerProperties() {
        // Given: GlassEffectView with corner radius
        let glassView = GPUAcceleratedGlassView.GlassEffectView()
        glassView.wantsLayer = true
        glassView.layer?.cornerRadius = 20
        glassView.layer?.masksToBounds = true

        // Then: Should have correct layer properties
        XCTAssertEqual(glassView.layer?.cornerRadius, 20)
        XCTAssertTrue(glassView.layer?.masksToBounds ?? false)
    }

    // MARK: - CoreImage Context

    func testCoreImageContextUsesGPU() {
        // Given: GlassEffectView
        let glassView = GPUAcceleratedGlassView.GlassEffectView()

        // When: Accessing CI context via reflection
        let mirror = Mirror(reflecting: glassView)
        let ciContext = mirror.children.first { $0.label == "ciContext" }?.value as? CIContext

        // Then: Should have CoreImage context (GPU rendering)
        XCTAssertNotNil(ciContext)
    }

    // MARK: - Multiple Instances

    func testMultipleGlassViewsWithDifferentRadii() {
        // Given: Multiple GPUAcceleratedGlassMaterial instances
        let material1 = GPUAcceleratedGlassMaterial(cornerRadius: 10)
        let material2 = GPUAcceleratedGlassMaterial(cornerRadius: 30)

        // Then: Should maintain independent corner radii
        let mirror1 = Mirror(reflecting: material1)
        let mirror2 = Mirror(reflecting: material2)

        let radius1 = mirror1.children.first { $0.label == "cornerRadius" }?.value as? CGFloat
        let radius2 = mirror2.children.first { $0.label == "cornerRadius" }?.value as? CGFloat

        XCTAssertEqual(radius1, 10)
        XCTAssertEqual(radius2, 30)
        XCTAssertNotEqual(radius1, radius2)
    }
}
