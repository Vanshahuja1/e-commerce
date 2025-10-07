"use client"

import React from "react"
import { useState, useEffect, useRef } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Switch } from "@/components/ui/switch"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { Alert, AlertDescription } from "@/components/ui/alert"
import {
  Users,
  Package,
  ShoppingCart,
  Eye,
  LogOut,
  RefreshCw as Refresh,
  Download,
  Plus,
  Upload,
  BarChart3,
  TrendingUp,
  Activity,
  DollarSign,
  Bell,
  Search,
  CheckCircle,
  XCircle,
  Clock,
  Truck,
  Trash,
} from "lucide-react"

import { API_BASE_URL } from "../../lib/config"
import { loadProducts, loadStats, loadUsers, loadOrders, getAuthHeaders } from "../../lib/data"
import { GroceryItems } from "../../lib/grocery-items"
interface InvoiceItem {
  name: string
  price: number
  quantity: number
}

// Lightweight horizontal image slider (scroll-snap) for up to 4 images
function ImageSlider({ urls }: { urls: string[] }) {
  const containerRef = useRef<HTMLDivElement | null>(null)
  const scrollBy = (delta: number) => {
    const el = containerRef.current
    if (!el) return
    el.scrollBy({ left: delta, behavior: "smooth" })
  }
  if (!urls || urls.length === 0) return null
  return (
    <div className="relative">
      <div
        ref={containerRef}
        className="flex overflow-x-auto no-scrollbar space-x-2 snap-x snap-mandatory w-64"
      >
        {urls.slice(0, 4).map((url, idx) => (
          <img
            key={idx}
            src={url}
            alt={`image ${idx + 1}`}
            className="snap-center shrink-0 w-24 h-24 md:w-16 md:h-16 object-cover rounded border border-gray-200 bg-white"
            onError={(e) => {
              (e.currentTarget as HTMLImageElement).src = "/placeholder.svg?thumb=1"
            }}
          />)
        )}
      </div>
      {urls.length > 1 && (
        <>
          <button
            type="button"
            onClick={() => scrollBy(-120)}
            className="absolute left-0 top-1/2 -translate-y-1/2 bg-white/80 hover:bg-white text-gray-700 border border-gray-200 rounded-full w-6 h-6 flex items-center justify-center shadow"
            aria-label="Previous"
          >
            ‹
          </button>
          <button
            type="button"
            onClick={() => scrollBy(120)}
            className="absolute right-0 top-1/2 -translate-y-1/2 bg-white/80 hover:bg-white text-gray-700 border border-gray-200 rounded-full w-6 h-6 flex items-center justify-center shadow"
            aria-label="Next"
          >
            ›
          </button>
        </>
      )}
    </div>
  )
}
interface User {
  _id: string
  name: string
  email: string
  phone: string
  userType: "buyer" | "seller" | "admin"
  isActive: boolean
  createdAt: string
}

interface Product {
  _id: string
  name: string
  productDetails: string
  price: number
  category: string
  imageUrls?: string[]
  images?: string[]
  imageUrl?: string
  videoUrl?: string
  quantity: number
  unit: string
  sellerId: string
  sellerName: string
  isAvailable: boolean
  createdAt: string
  discount?: number // Added for backend compatibility
  tax?: number      // Added for backend compatibility
  hasVAT?: boolean  // Added for backend compatibility
  discountPercent?: number
  taxPercent?: number
  applyVAT?: boolean
}

interface Order {
  _id: string
  orderId: string
  userId: string
  items: Array<{
    name: string
    price: number
    quantity: number
  }>
  address: {
    name: string
    phone: string
    address: string
    city: string
    state: string
    pincode: string
  }
  paymentMethod: string
  paymentStatus: string
  orderStatus: string
  totalAmount: number
  specialRequests?: string
  createdAt: string
}

interface Stats {
  totalUsers: number
  totalSellers: number
  pendingRequests: number
  activeSellers: number
  totalProducts: number
  availableProducts: number
  hiddenProducts: number
  totalOrders: number
}

export default function DashboardPage() {
  const [user, setUser] = useState<any>(null)
  const [stats, setStats] = useState<Stats>({
    totalUsers: 0,
    totalSellers: 0,
    pendingRequests: 0,
    activeSellers: 0,
    totalProducts: 0,
    availableProducts: 0,
    hiddenProducts: 0,
    totalOrders: 0,
  })
  const [users, setUsers] = useState<User[]>([])
  const [products, setProducts] = useState<Product[]>([])
  const [orders, setOrders] = useState<Order[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState("")
  const router = useRouter()

  // Product form state
  const [isAddingProduct, setIsAddingProduct] = useState(false)
  const [selectedImage, setSelectedImage] = useState<File | null>(null)
  const [selectedImages, setSelectedImages] = useState<File[]>([])
  const [selectedVideo, setSelectedVideo] = useState<File | null>(null)
  const [imageSelectionMode, setImageSelectionMode] = useState<"predefined" | "url" | "upload">("predefined")
  const [mediaUrlType, setMediaUrlType] = useState<"image" | "video">("image")
  const [selectedCategory, setSelectedCategory] = useState("Fruits")
  const [selectedPredefinedItem, setSelectedPredefinedItem] = useState<string | null>(null)
  // Client-side size caps to avoid 413 (Payload Too Large) from hosting proxy
  const MAX_IMAGE_SIZE = 10 * 1024 * 1024; // 10 MB
  const MAX_VIDEO_SIZE = 50 * 1024 * 1024; // 50 MB (matches backend Multer limit)
  const [productForm, setProductForm] = useState({
    name: "",
    productDetails: "",
    price: "",
    category: "Fruits",
    quantity: "",
    unit: "kg",
    imageUrl: "",
    videoUrl: "",
    discountPercent: "",
    taxPercent: "",
  })

  useEffect(() => {
    const token = localStorage.getItem("auth_token")
    const userData = localStorage.getItem("user_data")

    if (!token || !userData) {
      router.push("/login")
      return
    }

    const parsedUser = JSON.parse(userData)
    if (parsedUser.userType !== "admin") {
      router.push("/login")
      return
    }

    setUser(parsedUser)
    loadDashboardData()
  }, [router])

  const loadDashboardData = async () => {
    setIsLoading(true)
    try {
      const [statsData, usersData, productsData, ordersData] = await Promise.all([
        loadStats(),
        loadUsers(),
        loadProducts(),
        loadOrders(),
      ])

      if (statsData) setStats(statsData)
      setUsers(usersData)
      setProducts(productsData)
      setOrders(ordersData)
    } catch (error) {
      setError("Failed to load dashboard data")
    } finally {
      setIsLoading(false)
    }
  }

  const toggleUserStatus = async (userId: string, isActive: boolean) => {
    try {
      const response = await fetch(`${API_BASE_URL}/admin/users/${userId}/status`, {
        method: "PATCH",
        headers: getAuthHeaders({ json: true }),
        body: JSON.stringify({ isActive }),
      })
      const data = await response.json()
      if (data.success) {
        const updatedUsers = await loadUsers()
        setUsers(updatedUsers)
      }
    } catch (error) {
      console.error("Failed to toggle user status:", error)
    }
  }

  const toggleProductStatus = async (productId: string, isAvailable: boolean) => {
    try {
      const response = await fetch(`${API_BASE_URL}/admin/items/${productId}/status`, {
        method: "PATCH",
        headers: getAuthHeaders({ json: true }),
        body: JSON.stringify({ isAvailable }),
      })
      const data = await response.json()
      if (data.success) {
        const [updatedProducts, updatedStats] = await Promise.all([loadProducts(), loadStats()])
        setProducts(updatedProducts)
        if (updatedStats) setStats(updatedStats)
      }
    } catch (error) {
      console.error("Failed to toggle product status:", error)
    }
  }

  const deleteProduct = async (productId: string) => {
    const confirm = window.confirm("Delete this product? This action cannot be undone.")
    if (!confirm) return
    try {
      const response = await fetch(`${API_BASE_URL}/admin/items/${productId}`, {
        method: "DELETE",
        headers: getAuthHeaders(),
      })
      let data: any = {}
      try {
        data = await response.json()
      } catch (_) {}
      if (response.ok && (data.success === undefined || data.success)) {
        const [updatedProducts, updatedStats] = await Promise.all([loadProducts(), loadStats()])
        setProducts(updatedProducts)
        if (updatedStats) setStats(updatedStats)
      } else {
        setError(data.message || "Failed to delete product")
      }
    } catch (error) {
      console.error("Failed to delete product:", error)
      setError("Failed to delete product")
    }
  }

  const getPredefinedItemImageUrl = (itemName: string) => {
    return GroceryItems.getImageUrl(itemName)
  }

  const handlePredefinedImageSelect = (imageName: string) => {
    const imageUrl = getPredefinedItemImageUrl(imageName)
    setSelectedPredefinedItem(imageName)
    // Selecting an image from gallery clears any videoUrl to enforce single media
    setSelectedImage(null)
    setProductForm({ ...productForm, name: imageName, imageUrl: imageUrl || "", videoUrl: "" })
  }

  const handleCustomUrlChange = (url: string) => {
    setSelectedPredefinedItem(null)
    // Auto-detect by common video extensions if user forgets to toggle
    const isVideoLike = /\.(mp4|webm|ogg|mov|m4v)$/i.test(url)
    const targetType = isVideoLike ? "video" : mediaUrlType
    if (targetType === "image") {
      setSelectedImage(null)
      setProductForm({ ...productForm, imageUrl: url, videoUrl: "" })
    } else {
      setSelectedImage(null)
      setProductForm({ ...productForm, videoUrl: url, imageUrl: "" })
    }
  }

  // New: images (multi) upload handler
  const handleImagesUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(event.target.files || [])
    if (!files.length) return
    // Validate and cap at 4
    const imagesOnly = files.filter((f) => f.type.startsWith("image/"))
    for (const f of imagesOnly) {
      if (f.size > MAX_IMAGE_SIZE) {
        setError(`Image too large. Max ${Math.round(MAX_IMAGE_SIZE / (1024 * 1024))}MB allowed.`)
        return
      }
    }
    const combined = [...selectedImages, ...imagesOnly].slice(0, 4)
    setSelectedImages(combined)
    setSelectedPredefinedItem(null)
    // Clear URL previews to reflect file selection priority (server will use files)
    setProductForm({ ...productForm, imageUrl: combined.length ? URL.createObjectURL(combined[0]) : "", videoUrl: productForm.videoUrl })
  }

  // New: single video upload handler
  const handleVideoUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return
    if (!file.type.startsWith("video/")) {
      setError("Please select a video file.")
      return
    }
    if (file.size > MAX_VIDEO_SIZE) {
      setError(`Video too large. Max ${Math.round(MAX_VIDEO_SIZE / (1024 * 1024))}MB allowed.`)
      return
    }
    setSelectedVideo(file)
    setSelectedPredefinedItem(null)
    // Show local preview for video
    setProductForm({ ...productForm, videoUrl: URL.createObjectURL(file) })
  }

  

  const addProduct = async () => {
    try {
      console.log("[v0] Starting addProduct function")
      console.log("[v0] Selected predefined item:", selectedPredefinedItem)
      console.log("[v0] Product form imageUrl:", productForm.imageUrl)
      console.log("[v0] Image selection mode:", imageSelectionMode)

      const priceNum = Number.parseFloat(productForm.price)
      const quantityNum = Number.parseInt(productForm.quantity)
      console.log('[DEBUG] name:', productForm.name, '| price:', productForm.price, '| quantity:', productForm.quantity)
      console.log('[DEBUG] priceNum:', priceNum, '| quantityNum:', quantityNum)
      if (
        !productForm.name.trim() ||
        !productForm.productDetails.trim() ||
        isNaN(priceNum) || priceNum <= 0 ||
        isNaN(quantityNum) || quantityNum <= 0
      ) {
        setError("All required fields must be valid: name, product details, price > 0, quantity > 0")
        return
      }

      let finalImageUrl = productForm.imageUrl

      if (selectedPredefinedItem !== null) {
        const predefinedUrl = getPredefinedItemImageUrl(selectedPredefinedItem)
        finalImageUrl = predefinedUrl || productForm.imageUrl
        console.log("[v0] Using predefined item URL:", finalImageUrl)
      }

      // If any file(s) were chosen, upload via multipart
      let response: Response
      if (selectedImages.length > 0 || selectedVideo) {
        // Validate caps again and build FormData
        if (selectedImages.length > 4) {
          setError("Maximum 4 images allowed.")
          return
        }
        for (const img of selectedImages) {
          if (img.size > MAX_IMAGE_SIZE) {
            setError(`Image too large. Max ${Math.round(MAX_IMAGE_SIZE / (1024 * 1024))}MB allowed.`)
            return
          }
        }
        if (selectedVideo && selectedVideo.size > MAX_VIDEO_SIZE) {
          setError(`Video too large. Max ${Math.round(MAX_VIDEO_SIZE / (1024 * 1024))}MB allowed.`)
          return
        }

        const form = new FormData()
        selectedImages.forEach((img) => form.append("images", img))
        if (selectedVideo) form.append("video", selectedVideo)
        form.append("name", productForm.name)
        form.append("productDetails", productForm.productDetails)
        form.append("price", String(Number.parseFloat(productForm.price)))
        form.append("category", productForm.category)
        form.append("quantity", String(Number.parseInt(productForm.quantity)))
        form.append("unit", productForm.unit)
        form.append("isAvailable", "true")
        form.append("discount", String(productForm.discountPercent ? Number.parseFloat(productForm.discountPercent) : 0))
        form.append("tax", String(productForm.taxPercent ? Number.parseFloat(productForm.taxPercent) : 0))

        console.log("[v0] Sending multipart form with images/video. Fields:", Array.from(form.keys()))
        response = await fetch(`${API_BASE_URL}/admin/items`, {
          method: "POST",
          headers: {
            ...getAuthHeaders(),
          } as any,
          body: form,
        })
      } else {
        const urls = (finalImageUrl || '')
          .split(',')
          .map((u) => u.trim())
          .filter((u) => u.length > 0)
          .slice(0, 4)
        const productData = {
          name: productForm.name,
          productDetails: productForm.productDetails,
          price: Number.parseFloat(productForm.price),
          category: productForm.category,
          quantity: Number.parseInt(productForm.quantity),
          unit: productForm.unit,
          imageUrls: urls,
          videoUrl: productForm.videoUrl || undefined,
          isAvailable: true,
          discount: productForm.discountPercent ? Number.parseFloat(productForm.discountPercent) : 0,
          tax: productForm.taxPercent ? Number.parseFloat(productForm.taxPercent) : 0,
        }
        console.log("[v0] Final product data being sent:", productData)
        // Use explicit JSON endpoint for URL-based adds
        response = await fetch(`${API_BASE_URL}/admin/items/json`, {
          method: "POST",
          headers: {
            ...getAuthHeaders({ json: true }),
          },
          body: JSON.stringify(productData),
        })
      }

      console.log("[v0] Response status:", response.status)
      // Be resilient to HTML error pages or non-JSON bodies
      let data: any
      const rawText = await response.text()
      try {
        data = rawText ? JSON.parse(rawText) : {}
      } catch (e) {
        console.warn("[v0] Non-JSON response:", rawText)
        data = { success: false, message: rawText }
      }
      console.log("[v0] Add product response:", data)

      if (data.success) {
        setProductForm({
          name: "",
          productDetails: "",
          price: "",
          category: "Fruits",
          quantity: "",
          unit: "kg",
          imageUrl: "",
          videoUrl: "",
          discountPercent: "",
          taxPercent: "",
        })
        setSelectedImage(null)
        setSelectedImages([])
        setSelectedVideo(null)
        setSelectedPredefinedItem(null)
        setImageSelectionMode("predefined")
        setIsAddingProduct(false)

        const [updatedProducts, updatedStats] = await Promise.all([loadProducts(), loadStats()])
        setProducts(updatedProducts)
        if (updatedStats) setStats(updatedStats)
      } else {
        console.error("[v0] Add product failed:", data.message)
        setError(data.message || "Failed to add product")
      }
    } catch (error) {
      console.error("[v0] Add product error:", error)
      setError("Failed to add product. Please try again.")
    }
  }

  const downloadInvoice = async (order: Order) => {
    try {
      const response = await fetch(`${API_BASE_URL}/admin/orders/${order.orderId}/invoice/data`, {
        headers: getAuthHeaders(),
      })
      const data = await response.json()

      if (data.success) {
        const invoiceData = data.invoiceData
        const invoiceHTML = `
          <!DOCTYPE html>
          <html>
          <head>
            <title>Invoice - ${order.orderId}</title>
            <style>
              body { font-family: Arial, sans-serif; margin: 20px; color: #030303ff; }
              .header { text-align: center; margin-bottom: 30px; background: linear-gradient(135deg, #e17272ff, #f37272ff); color: white; padding: 20px; border-radius: 8px; }
              .company-name { font-size: 28px; font-weight: bold; margin-bottom: 5px; }
              .order-info { margin-bottom: 20px; background: #fdf0f0ff; padding: 15px; border-radius: 8px; border-left: 4px solid #000000ff; }
              .items-table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
              .items-table th, .items-table td { border: 1px solid #f6cac7ff; padding: 12px; text-align: left; }
              .items-table th { background-color: #fcdcdcff; color: #000000ff; font-weight: bold; }
              .total { text-align: right; font-weight: bold; font-size: 18px; background: #fdf0f0ff; padding: 15px; border-radius: 8px; }
              .special-requests { background: #f9e597ff; padding: 15px; border-radius: 8px; border-left: 4px solid #9e6605ff; margin-bottom: 20px; }
            </style>
          </head>
          <body>
            <div class="header">
              <div class="company-name">Kanwarji's</div>
              <h2>INVOICE</h2>
              <h3>Order ID: ${order.orderId}</h3>
            </div>
            <div class="order-info">
              <p><strong>Date:</strong> ${new Date(order.createdAt).toLocaleDateString()}</p>
              <p><strong>Customer:</strong> ${invoiceData.customer.name}</p>
              <p><strong>Phone:</strong> ${invoiceData.customer.phone}</p>
              <p><strong>Email:</strong> ${invoiceData.customer.email}</p>
              <p><strong>Address:</strong> ${invoiceData.customer.address.address}, ${invoiceData.customer.address.city}, ${invoiceData.customer.address.state} - ${invoiceData.customer.address.pincode}</p>
              <p><strong>Payment Method:</strong> ${invoiceData.order.paymentMethod.toUpperCase()}</p>
              <p><strong>Payment Status:</strong> ${invoiceData.order.paymentStatus.toUpperCase()}</p>
              <p><strong>Order Status:</strong> ${invoiceData.order.orderStatus.toUpperCase()}</p>
            </div>
            ${
              order.specialRequests
                ? `
            <div class="special-requests">
              <h4 style="margin: 0 0 10px 0; color: #92400e;">Special Requests:</h4>
              <p style="margin: 0;">${order.specialRequests}</p>
            </div>`
                : ""
            }
            <table class="items-table">
              <thead>
                <tr>
                  <th>Item</th>
                  <th>Quantity</th>
                  <th>Price</th>
                  <th>Total</th>
                </tr>
              </thead>
              <tbody>
                ${invoiceData.order.items
                  .map(
                    (item:InvoiceItem) => `
                  <tr>
                    <td>${item.name}</td>
                    <td>${item.quantity}</td>
                    <td>₹ ${item.price}</td>
                    <td>₹ ${(item.price * item.quantity).toFixed(2)}</td>
                  </tr>
                `,
                  )
                  .join("")}
              </tbody>
            </table>
            <div class="total">
              <p>Subtotal: ₹ ${invoiceData.order.subtotal?.toFixed(2) || "0.00"}</p>
              <p>Delivery Fee: ₹ ${invoiceData.order.deliveryFee?.toFixed(2) || "0.00"}</p>
              <p>Tax: ₹ ${invoiceData.order.taxAmount?.toFixed(2) || "0.00"}</p>
              <p style="font-size: 20px; margin-top: 10px;">Total Amount: ₹ ${invoiceData.order.totalAmount.toFixed(2)}</p>
            </div>
            <div style="margin-top: 30px; text-align: center; color: #666; font-size: 12px;">
              <p>Thank you for shopping with Kanwarji's!</p>
              <p>Everything delivered to your door.</p>
            </div>
          </body>
          </html>
        `

        const blob = new Blob([invoiceHTML], { type: "text/html" })
        const url = URL.createObjectURL(blob)
        const a = document.createElement("a")
        a.href = url
        a.download = `Kanwarji's-invoice-${order.orderId}.html`
        document.body.appendChild(a)
        a.click()
        document.body.removeChild(a)
        URL.revokeObjectURL(url)
      }
    } catch (error) {
      console.error("Failed to download invoice:", error)
      setError("Failed to download invoice")
    }
  }

  const handleLogout = () => {
    localStorage.removeItem("auth_token")
    localStorage.removeItem("user_data")
    router.push("/login")
  }

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="flex flex-col items-center space-y-4">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-red-400"></div>
          <div className="text-gray-600 font-medium">Loading dashboard...</div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-white border-b border-gray-200 shadow-sm">
        <div className="px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
               <div  >
  <img 
    src="/logo1.png"
    alt="cart"
    className="h-20 w-20 object-contain"
  />
</div>
              <div>
                <h1 className="text-2xl font-bold text-gray-900">Admin</h1>
                <p className="text-gray-600 text-sm">Kanwarji's Management Dashboard</p>
              </div>
            </div>
            <div className="flex items-center space-x-4">
              <Button
                variant="outline"
                size="sm"
                onClick={loadDashboardData}
                className="border-gray-300 text-gray-700 hover:bg-gray-50 bg-transparent"
              >
                <Refresh className="h-4 w-4 mr-2" />
                Refresh
              </Button>
              <div className="flex items-center space-x-3">
                <div className="bg-red-50 px-3 py-2 rounded-lg">
                  <span className="text-red-400 font-medium text-sm">Welcome, {user?.name}</span>
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleLogout}
                  className="border-red-300 text-red-700 hover:bg-red-50 bg-transparent"
                >
                  <LogOut className="h-4 w-4 mr-2" />
                  Logout
                </Button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {error && (
        <div className="mx-6 mt-4">
          <Alert className="bg-red-50 border-red-200">
            <XCircle className="h-4 w-4 text-red-600" />
            <AlertDescription className="text-red-800">{error}</AlertDescription>
          </Alert>
        </div>
      )}

      <div className="p-6">
        <Tabs defaultValue="overview" className="space-y-6">
          <TabsList className="bg-white border border-gray-200 shadow-sm p-1">
            <TabsTrigger
              value="overview"
              className="data-[state=active]:bg-red-400 data-[state=active]:text-white data-[state=active]:shadow-sm"
            >
              <BarChart3 className="h-4 w-4 mr-2" />
              Overview
            </TabsTrigger>
            <TabsTrigger
              value="users"
              className="data-[state=active]:bg-red-400 data-[state=active]:text-white data-[state=active]:shadow-sm"
            >
              <Users className="h-4 w-4 mr-2" />
              Users
            </TabsTrigger>
            <TabsTrigger
              value="products"
              className="data-[state=active]:bg-red-400 data-[state=active]:text-white data-[state=active]:shadow-sm"
            >
              <Package className="h-4 w-4 mr-2" />
              Products
            </TabsTrigger>
            <TabsTrigger
              value="orders"
              className="data-[state=active]:bg-red-400 data-[state=active]:text-white data-[state=active]:shadow-sm"
            >
              <ShoppingCart className="h-4 w-4 mr-2" />
              Orders
            </TabsTrigger>
          </TabsList>

          <TabsContent value="overview" className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              <Card className="bg-white border border-gray-200 shadow-sm hover:shadow-md transition-shadow">
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium text-gray-600">Total Users</CardTitle>
                  <div className="bg-blue-100 p-2 rounded-lg">
                    <Users className="h-4 w-4 text-blue-600" />
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-gray-900">{stats.totalUsers}</div>
                  <div className="flex items-center mt-2">
                    <TrendingUp className="h-3 w-3 text-red-400 mr-1" />
                    <span className="text-xs text-red-400 font-medium">Active users</span>
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-white border border-gray-200 shadow-sm hover:shadow-md transition-shadow">
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium text-gray-600">Total Products</CardTitle>
                  <div className="bg-red-100 p-2 rounded-lg">
                    <Package className="h-4 w-4 text-red-400" />
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-gray-900">{stats.totalProducts}</div>
                  <div className="flex items-center mt-2">
                    <Activity className="h-3 w-3 text-red-400 mr-1" />
                    <span className="text-xs text-red-400 font-medium">{stats.availableProducts} available</span>
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-white border border-gray-200 shadow-sm hover:shadow-md transition-shadow">
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium text-gray-600">Available Products</CardTitle>
                  <div className="bg-emerald-100 p-2 rounded-lg">
                    <Eye className="h-4 w-4 text-emerald-600" />
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-gray-900">{stats.availableProducts}</div>
                  <div className="flex items-center mt-2">
                    <CheckCircle className="h-3 w-3 text-emerald-600 mr-1" />
                    <span className="text-xs text-emerald-600 font-medium">Ready to sell</span>
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-white border border-gray-200 shadow-sm hover:shadow-md transition-shadow">
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium text-gray-600">Total Orders</CardTitle>
                  <div className="bg-orange-100 p-2 rounded-lg">
                    <ShoppingCart className="h-4 w-4 text-orange-600" />
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-gray-900">{stats.totalOrders}</div>
                  <div className="flex items-center mt-2">
                    <div className="text-xs text-orange-600">₹ </div>
                    <span className="text-xs text-orange-600 font-medium">-All time</span>
                  </div>
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          <TabsContent value="users" className="space-y-6">
            <Card className="bg-white border border-gray-200 shadow-sm">
              <CardHeader className="border-b border-gray-100">
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle className="text-gray-900 flex items-center">
                      <Users className="h-5 w-5 mr-2 text-red-400" />
                      User Management
                    </CardTitle>
                    <CardDescription className="text-gray-600">Manage user accounts and permissions</CardDescription>
                  </div>
                
                </div>
              </CardHeader>
              <CardContent className="p-6">
                <div className="space-y-4">
                  {users.map((user) => (
                    <div
                      key={user._id}
                      className="flex items-center justify-between p-4 bg-gray-50 rounded-lg border border-gray-200 hover:bg-gray-100 transition-colors"
                    >
                      <div className="flex items-center space-x-4">
                        <div className="bg-red-100 p-2 rounded-full">
                          <Users className="h-4 w-4 text-red-400" />
                        </div>
                        <div className="flex-1">
                          <div className="font-medium text-gray-900">{user.name}</div>
                          <div className="text-sm text-gray-600">{user.email}</div>
                          <div className="text-sm text-gray-500">{user.phone}</div>
                          <Badge
                            variant={user.userType === "admin" ? "default" : "secondary"}
                            className={
                              user.userType === "admin"
                                ? "bg-red-400 hover:bg-red-400"
                                : "bg-gray-100 text-gray-700"
                            }
                          >
                            {user.userType}
                          </Badge>
                        </div>
                      </div>
                      <div className="flex items-center space-x-3">
                        <span className={`text-sm font-medium ${user.isActive ? "text-red-400" : "text-gray-500"}`}>
                          {user.isActive ? "Active" : "Inactive"}
                        </span>
                        <Switch
                          checked={user.isActive}
                          onCheckedChange={(checked) => toggleUserStatus(user._id, checked)}
                          className="data-[state=checked]:bg-red-400"
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="products" className="space-y-6">
            <Card className="bg-white border border-gray-200 shadow-sm">
              <CardHeader className="border-b border-gray-100">
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle className="text-gray-900 flex items-center">
                      <Package className="h-5 w-5 mr-2 text-red-400" />
                      Product Management
                    </CardTitle>
                    <CardDescription className="text-gray-600">Manage fresh products and inventory</CardDescription>
                  </div>
                  <Button
                    onClick={() => setIsAddingProduct(!isAddingProduct)}
                    className="bg-red-400 hover:bg-red-400 text-white shadow-sm"
                  >
                    <Plus className="h-4 w-4 mr-2" />
                    Add Product
                  </Button>
                </div>
              </CardHeader>
              <CardContent className="p-6 space-y-6">
                {isAddingProduct && (
                  <div className="p-6 bg-red-50 rounded-lg border border-red-200 space-y-6">
                    <div className="flex items-center space-x-2">
                      <div className="bg-red-400 p-2 rounded-lg">
                        <Plus className="h-4 w-4 text-white" />
                      </div>
                      <h3 className="text-lg font-semibold text-gray-900">Add New Product</h3>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                      <div className="space-y-2">
                        <Label htmlFor="name" className="text-gray-700 font-medium">
                          Product Name *
                        </Label>
                        <Input
                          id="name"
                          value={productForm.name}
                          onChange={(e) => setProductForm({ ...productForm, name: e.target.value })}
                          className="border-gray-300 focus:border-red-400 focus:ring-red-400"
                          placeholder="Enter product name"
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="price" className="text-gray-700 font-medium">
                          Price (₹) *
                        </Label>
                        <Input
                          id="price"
                          type="number"
                          step="0.01"
                          value={productForm.price}
                          onChange={(e) => setProductForm({ ...productForm, price: e.target.value })}
                          className="border-gray-300 focus:border-red-400 focus:ring-red-400"
                          placeholder="0.00"
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="category" className="text-gray-700 font-medium">
                          Category
                        </Label>
                        <Select
                          value={productForm.category}
                          onValueChange={(value) => {
                            setProductForm({ ...productForm, category: value })
                            setSelectedCategory(value)
                          }}
                        >
                          <SelectTrigger className="border-gray-300 focus:border-red-400 focus:ring-red-400">
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent className="bg-white border-gray-200">
                            <SelectItem value="Savory">Savory</SelectItem>
                            <SelectItem value="Namkeen"> Namkeen</SelectItem>
                            <SelectItem value="Sweets"> Sweets</SelectItem>
                            <SelectItem value="Travel Pack Combo">Travel Pack Combo</SelectItem>
                            <SelectItem value="Value Pack Offers">Value Pack Offers</SelectItem>
                            <SelectItem value="Gift Packs"> Gift Packs</SelectItem>
        
                          </SelectContent>
                        </Select>
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="quantity" className="text-gray-700 font-medium">
                          Quantity *
                        </Label>
                        <Input
                          id="quantity"
                          type="number"
                          value={productForm.quantity}
                          onChange={(e) => setProductForm({ ...productForm, quantity: e.target.value })}
                          className="border-gray-300 focus:border-red-400 focus:ring-red-400"
                          placeholder="Enter quantity"
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="unit" className="text-gray-700 font-medium">
                          Unit
                        </Label>
                        <Select
                          value={productForm.unit}
                          onValueChange={(value) => setProductForm({ ...productForm, unit: value })}
                        >
                          <SelectTrigger className="border-gray-300 focus:border-red-400 focus:ring-red-400">
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent className="bg-white border-gray-200">
                            <SelectItem value="kg">Kilogram (kg)</SelectItem>
                            <SelectItem value="g">Gram (g)</SelectItem>
                            <SelectItem value="lb">Pound (lb)</SelectItem>
                            <SelectItem value="oz">Ounce (oz)</SelectItem>
                            <SelectItem value="piece">Pieces</SelectItem>
                            <SelectItem value="pack">Packets</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="discount" className="text-gray-700 font-medium">
                          Discount (%)
                        </Label>
                        <Input
                          id="discount"
                          type="number"
                          step="0.01"
                          min="0"
                          max="100"
                          value={productForm.discountPercent}
                          onChange={(e) => setProductForm({ ...productForm, discountPercent: e.target.value })}
                          className="border-gray-300 focus:border-red-400 focus:ring-red-400"
                          placeholder="0.00"
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="tax" className="text-gray-700 font-medium">
                          Tax (%)
                        </Label>
                        <Input
                          id="tax"
                          type="number"
                          step="0.01"
                          min="0"
                          max="100"
                          value={productForm.taxPercent}
                          onChange={(e) => setProductForm({ ...productForm, taxPercent: e.target.value })}
                          className="border-gray-300 focus:border-red-400 focus:ring-red-400"
                          placeholder="0.00"
                        />
                      </div>
                    </div>

                    <div className="space-y-4">
                      <Label className="text-gray-700 font-medium">Product Media</Label>

                      {/* Image selection mode tabs */}
                      <div className="flex space-x-2">
                        <Button
                          type="button"
                          variant={imageSelectionMode === "predefined" ? "default" : "outline"}
                          size="sm"
                          onClick={() => setImageSelectionMode("predefined")}
                          className={
                            imageSelectionMode === "predefined"
                              ? "bg-red-400 hover:bg-red-400"
                              : "border-gray-300 text-gray-700 hover:bg-gray-50"
                          }
                        >
                          Choose from Gallery
                        </Button>
                        <Button
                          type="button"
                          variant={imageSelectionMode === "url" ? "default" : "outline"}
                          size="sm"
                          onClick={() => setImageSelectionMode("url")}
                          className={
                            imageSelectionMode === "url"
                              ? "bg-red-400 hover:bg-red-400"
                              : "border-gray-300 text-gray-700 hover:bg-gray-50"
                          }
                        >
                          Custom URL
                        </Button>
                        <Button
                          type="button"
                          variant={imageSelectionMode === "upload" ? "default" : "outline"}
                          size="sm"
                          onClick={() => setImageSelectionMode("upload")}
                          className={
                            imageSelectionMode === "upload"
                              ? "bg-red-400 hover:bg-red-400"
                              : "border-gray-300 text-gray-700 hover:bg-gray-50"
                          }
                        >
                          Upload
                        </Button>
                        
                      </div>

                      {/* Predefined images selection */}
                      {imageSelectionMode === "predefined" && (
                        <div className="space-y-3">
                          <div className="grid grid-cols-4 md:grid-cols-6 lg:grid-cols-8 gap-3 max-h-60 overflow-y-auto p-4 bg-white rounded-lg border border-gray-200">
                            {GroceryItems.getItemsByCategory(selectedCategory).map((imageName) => {
                              const imageUrl = GroceryItems.getImageUrl(imageName)
                              const isSelected = selectedPredefinedItem === imageName

                              return (
                                <div
                                  key={imageName}
                                  className={`cursor-pointer border-2 rounded-lg overflow-hidden transition-all hover:shadow-md ${
                                    isSelected
                                      ? "border-red-400 ring-2 ring-red-200"
                                      : "border-gray-200 hover:border-red-300"
                                  }`}
                                  onClick={() => handlePredefinedImageSelect(imageName)}
                                >
                                  <img
                                    src={imageUrl || "/placeholder.svg"}
                                    alt={imageName}
                                    className="w-full h-16 object-cover"
                                  />
                                  <div className="p-2 bg-gray-50">
                                    <div className="text-xs text-gray-700 text-center truncate font-medium">
                                      {imageName}
                                    </div>
                                  </div>
                                </div>
                              )
                            })}
                          </div>
                        </div>
                      )}

                      {/* Custom URL input */}
                      {imageSelectionMode === "url" && (
                        <div className="space-y-2">
                          <div className="flex space-x-2">
                            <Button
                              type="button"
                              variant={mediaUrlType === "image" ? "default" : "outline"}
                              size="sm"
                              onClick={() => setMediaUrlType("image")}
                              className={
                                mediaUrlType === "image"
                                  ? "bg-red-400 hover:bg-red-400"
                                  : "border-gray-300 text-gray-700 hover:bg-gray-50"
                              }
                            >
                              Image URL
                            </Button>
                            <Button
                              type="button"
                              variant={mediaUrlType === "video" ? "default" : "outline"}
                              size="sm"
                              onClick={() => setMediaUrlType("video")}
                              className={
                                mediaUrlType === "video"
                                  ? "bg-red-400 hover:bg-red-400"
                                  : "border-gray-300 text-gray-700 hover:bg-gray-50"
                              }
                            >
                              Video URL
                            </Button>
                          </div>
                          <Input
                            placeholder={mediaUrlType === "image" ? "Enter image URL (e.g., https://example.com/image.jpg)" : "Enter video URL (e.g., https://example.com/video.mp4)"}
                            value={mediaUrlType === "image" ? productForm.imageUrl : productForm.videoUrl}
                            onChange={(e) => handleCustomUrlChange(e.target.value)}
                            className="border-gray-300 focus:border-red-400 focus:ring-red-400"
                          />
                          {mediaUrlType === 'image' && (
                            <div className="text-xs text-gray-500">Tip: Add multiple image URLs separated by commas.</div>
                          )}
                        </div>
                      )}

                      {/* File upload */}
                      {imageSelectionMode === "upload" && (
                        <div className="space-y-3">
                          <div className="flex items-center space-x-4">
                            <div className="flex-1">
                              <Label className="text-gray-700">Images (max 4)</Label>
                              <Input
                                type="file"
                                multiple
                                accept="image/*"
                                onChange={handleImagesUpload}
                                className="mt-1 border-gray-300 focus:border-red-400 focus:ring-red-400 file:bg-red-400 file:text-white file:border-0 file:rounded file:px-4 file:py-2"
                              />
                            </div>
                            <div className="flex-1">
                              <Label className="text-gray-700">Video (optional)</Label>
                              <Input
                                type="file"
                                accept="video/*"
                                onChange={handleVideoUpload}
                                className="mt-1 border-gray-300 focus:border-red-400 focus:ring-red-400 file:bg-red-400 file:text-white file:border-0 file:rounded file:px-4 file:py-2"
                              />
                            </div>
                          </div>
                        </div>
                      )}

                      {/* Media preview */
                      }
                      {imageSelectionMode === "upload" && selectedImages.length > 0 && (
                        <div className="p-4 bg-white rounded-lg border border-gray-200">
                          <div className="text-gray-700 text-sm font-medium mb-2">Image Previews:</div>
                          <ImageSlider urls={selectedImages.slice(0, 4).map((img) => URL.createObjectURL(img))} />
                        </div>
                      )}
                      {productForm.imageUrl && imageSelectionMode === "url" && mediaUrlType === 'image' && (
                        <div className="p-4 bg-white rounded-lg border border-gray-200">
                          <div className="text-gray-700 text-sm font-medium mb-2">Preview:</div>
                          {(() => {
                            const urls = productForm.imageUrl
                              .split(',')
                              .map((u) => u.trim())
                              .filter(Boolean)
                              .slice(0, 4)
                            return <ImageSlider urls={urls} />
                          })()}
                        </div>
                      )}
                      {productForm.imageUrl && imageSelectionMode !== "upload" && !(imageSelectionMode === "url" && mediaUrlType === 'image') && (
                        <div className="p-4 bg-white rounded-lg border border-gray-200">
                          <div className="text-gray-700 text-sm font-medium mb-2">Preview:</div>
                          <ImageSlider urls={[productForm.imageUrl]} />
                        </div>
                      )}
                      {(imageSelectionMode === "upload" && selectedVideo) ? (
                        <div className="flex items-center space-x-4 p-4 bg-white rounded-lg border border-gray-200">
                          <div className="text-gray-700 text-sm font-medium">Video Preview:</div>
                          <video
                            src={productForm.videoUrl}
                            controls
                            className="w-48 h-28 rounded-lg border border-gray-200 bg-black"
                          />
                          <div className="text-xs text-gray-500 max-w-xs truncate">{selectedVideo.name}</div>
                        </div>
                      ) : (
                        productForm.videoUrl && (
                        <div className="flex items-center space-x-4 p-4 bg-white rounded-lg border border-gray-200">
                          <div className="text-gray-700 text-sm font-medium">Preview:</div>
                          <video
                            src={productForm.videoUrl}
                            controls
                            className="w-48 h-28 rounded-lg border border-gray-200 bg-black"
                          />
                          <div className="text-xs text-gray-500 max-w-xs truncate">{productForm.videoUrl}</div>
                        </div>
                        )
                      )}
                    </div>

                    

                    <div className="space-y-2">
                          <Label htmlFor="productDetails" className="text-gray-700 font-medium">
                            Product Details
                          </Label>
                          <Textarea
                            id="productDetails"
                            value={productForm.productDetails}
                            onChange={(e) => setProductForm({ ...productForm, productDetails: e.target.value })}
                            className="border-gray-300 focus:border-red-400 focus:ring-red-400"
                            placeholder="Enter product details..."
                            rows={3}
                          />
                    </div>

                    <div className="flex space-x-3 pt-4">
                      <Button onClick={addProduct} className="bg-red-400 hover:bg-red-400 text-white">
                        <Plus className="h-4 w-4 mr-2" />
                        Add Product
                      </Button>
                      <Button
                        variant="outline"
                        onClick={() => {
                          setIsAddingProduct(false)
                          setSelectedImage(null)
                          setSelectedPredefinedItem(null)
                          setImageSelectionMode("predefined")
                          setProductForm({
                            name: "",
                            productDetails: "",
                            price: "",
                            category: "Fruits",
                            quantity: "",
                            unit: "kg",
                            imageUrl: "",
                            videoUrl: "",
                            discountPercent: "",
                            taxPercent: "",
                          })
                          setMediaUrlType("image")
                        }}
                        className="border-gray-300 text-gray-700 hover:bg-gray-50"
                      >
                        Cancel
                      </Button>
                    </div>
                  </div>
                )}

                <div className="space-y-4">
                  {products.map((product) => (
                    <div
                      key={product._id}
                      className="flex items-center justify-between p-4 bg-gray-50 rounded-lg border border-gray-200 hover:bg-gray-100 transition-colors"
                    >
                      <div className="flex items-center space-x-4">
                        {/* Media thumbnails with slider (up to 4) */}
                        {product.images && product.images.length > 0 ? (
                          <ImageSlider urls={product.images} />
                        ) : product.imageUrls && product.imageUrls.length > 0 ? (
                          <ImageSlider urls={product.imageUrls} />
                        ) : product.imageUrl ? (
                          <img
                            src={product.imageUrl}
                            alt={product.name}
                            className="w-16 h-16 object-cover rounded border border-gray-200"
                            onError={(e) => {
                              (e.currentTarget as HTMLImageElement).src = "/placeholder.svg?thumb=1"
                            }}
                          />
                        ) : product.videoUrl ? (
                          <video
                            src={product.videoUrl}
                            className="w-24 h-16 rounded border border-gray-200 bg-black"
                            muted
                            controls
                          />
                        ) : (
                          <div className="bg-red-100 p-2 rounded-lg">
                            <Package className="h-4 w-4 text-red-400" />
                          </div>
                        )}
                        <div className="flex-1">
                          <div className="font-medium text-gray-900">{product.name}</div>
                          <div className="text-sm text-gray-600">{product.productDetails}</div>
                          <div className="text-sm text-gray-600 mt-1">
                            <span className="font-semibold text-gray-900">₹ {product.price}</span>
                            <span className="text-gray-500"> / {product.unit}</span>
                          </div>
                          <div className="text-sm text-gray-500">Seller: {product.sellerName}</div>
                          <div className="text-sm text-gray-500">
                              <span className="font-semibold text-red-400">Discount:</span> {product.discount || product.discountPercent || 0}% |{' '}
                              <span className="font-semibold text-blue-700">Tax:</span> {product.tax || product.taxPercent || 0}%
                          </div>
                        </div>
                      </div>
                      <div className="flex items-center space-x-3">
                        <Badge
                          variant={product.isAvailable ? "default" : "secondary"}
                          className={
                            product.isAvailable ? "bg-red-400 hover:bg-red-400" : "bg-gray-100 text-gray-700"
                          }
                        >
                          {product.isAvailable ? "Visible" : "Hidden"}
                        </Badge>
                        <Switch
                          checked={product.isAvailable}
                          onCheckedChange={(checked) => toggleProductStatus(product._id, checked)}
                          className="data-[state=checked]:bg-red-400"
                        />
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => deleteProduct(product._id)}
                          className="border-red-300 text-red-700 hover:bg-red-50"
                        >
                          <Trash className="h-4 w-4 mr-1" />
                          Delete
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="orders" className="space-y-6">
            <Card className="bg-white border border-gray-200 shadow-sm">
              <CardHeader className="border-b border-gray-100">
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle className="text-gray-900 flex items-center">
                      <ShoppingCart className="h-5 w-5 mr-2 text-red-400" />
                      Order Management
                    </CardTitle>
                    <CardDescription className="text-gray-600">View and manage customer orders</CardDescription>
                  </div>
                  
                </div>
              </CardHeader>
              <CardContent className="p-6">
                <div className="space-y-6">
                  {orders.map((order) => (
                    <div key={order._id} className="p-6 bg-gray-50 rounded-lg border border-gray-200">
                      <div className="flex items-center justify-between mb-4">
                        <div className="flex items-center space-x-4">
                          <div className="bg-red-100 p-2 rounded-lg">
                            <ShoppingCart className="h-5 w-5 text-red-400" />
                          </div>
                          <div>
                            <div className="font-semibold text-gray-900">Order #{order.orderId}</div>
                            <div className="text-sm text-gray-600">
                              {new Date(order.createdAt).toLocaleDateString()}
                            </div>
                          </div>
                        </div>
                        <div className="flex items-center space-x-3">
                          <Badge
                            variant="outline"
                            className={`border-gray-300 ${
                              order.orderStatus === "delivered"
                                ? "text-red-400 bg-red-50 border-red-200"
                                : order.orderStatus === "pending"
                                  ? "text-orange-700 bg-orange-50 border-orange-200"
                                  : "text-gray-700 bg-gray-50"
                            }`}
                          >
                            {order.orderStatus === "delivered" && <CheckCircle className="h-3 w-3 mr-1" />}
                            {order.orderStatus === "pending" && <Clock className="h-3 w-3 mr-1" />}
                            {order.orderStatus === "shipped" && <Truck className="h-3 w-3 mr-1" />}
                            {order.orderStatus}
                          </Badge>
                          <Badge
                            variant="outline"
                            className={`border-gray-300 ${
                              order.paymentStatus === "paid"
                                ? "text-red-400 bg-red-50 border-red-200"
                                : order.paymentStatus === "pending"
                                  ? "text-orange-700 bg-orange-50 border-orange-200"
                                  : "text-red-700 bg-red-50 border-red-200"
                            }`}
                          >
                            {order.paymentStatus}
                          </Badge>
                          <Button
                            size="sm"
                            onClick={() => downloadInvoice(order)}
                            className="bg-red-400 hover:bg-red-400 text-white"
                          >
                            <Download className="h-4 w-4 mr-2" />
                            Invoice
                          </Button>
                        </div>
                      </div>

                      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 text-sm">
                        <div className="space-y-2">
                          <div className="text-gray-500 font-medium">Customer Information</div>
                          <div className="bg-white p-3 rounded border border-gray-200">
                            <div className="font-medium text-gray-900">{order.address.name}</div>
                            <div className="text-gray-600">{order.address.phone}</div>
                            <div className="text-gray-600 text-xs mt-1">
                              {order.address.address}, {order.address.city}, {order.address.state} -{" "}
                              {order.address.pincode}
                            </div>
                          </div>
                        </div>
                        <div className="space-y-2">
                          <div className="text-gray-500 font-medium">Order Summary</div>
                          <div className="bg-white p-3 rounded border border-gray-200">
                            <div className="flex justify-between items-center">
                              <span className="text-gray-600">Total Amount:</span>
                              <span className="font-semibold text-gray-900">₹ {order.totalAmount}</span>
                            </div>
                            <div className="text-gray-600 text-sm mt-1">
                              Payment: {order.paymentMethod.toUpperCase()}
                            </div>
                          </div>
                        </div>
                      </div>

                      {order.specialRequests && (
                        <div className="mt-4 p-3 bg-yellow-100 border border-yellow-500 rounded-lg">
                          <div className="flex items-center space-x-2 mb-2">
                            <Bell className="h-4 w-4 text-yellow-800" />
                            <div className="text-yellow-800 text-sm font-medium">Special Requests:</div>
                          </div>
                          <div className="text-yellow-900 text-sm">{order.specialRequests}</div>
                        </div>
                      )}

                      <div className="mt-4">
                        <div className="text-gray-500 text-sm font-medium mb-3">Order Items</div>
                        <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
                          <div className="divide-y divide-gray-100">
                            {order.items.map((item, index) => (
                              <div key={index} className="flex justify-between items-center p-3">
                                <div className="flex items-center space-x-3">
                                  <div className="bg-red-100 p-1 rounded">
                                    <Package className="h-3 w-3 text-red-400" />
                                  </div>
                                  <span className="text-gray-900 font-medium">{item.name}</span>
                                  <span className="text-gray-500 text-sm">× {item.quantity}</span>
                                </div>
                                <span className="font-medium text-gray-900">
                                  ₹ {(item.price * item.quantity).toFixed(2)}
                                </span>
                              </div>
                            ))}
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  )
}
