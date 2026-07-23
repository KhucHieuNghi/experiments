import { useLocation, Link } from "react-router"
import {
  Play,
  FileText,
  Webhook,
  FolderOpen,
  BrainCircuit,
  BarChart3,
  SlidersHorizontal,
  Sun,
  Moon,
  ChevronLeft,
  ChevronRight,
} from "lucide-react"
import { EtusLogo } from "@/components/icons/etus-logo"
import { routes } from "@/lib/routes"

import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarRail,
  SidebarSeparator,
  useSidebar,
} from "@/components/ui/sidebar"
import { useTheme } from "@/components/theme-provider"

const navItems = [
  { title: "Runs", url: routes.runs, icon: Play, tourId: "tour-nav-runs" },
  { title: "Tests", url: routes.tests, icon: FileText, tourId: "tour-nav-tests" },
  { title: "Hooks", url: routes.hooks, icon: Webhook, tourId: "tour-nav-hooks" },
  { title: "Suites", url: routes.suites, icon: FolderOpen, tourId: "tour-nav-suites" },
  { title: "Memory", url: routes.memory, icon: BrainCircuit, tourId: "tour-nav-memory" },
  { title: "Insights", url: routes.insights, icon: BarChart3 },
  { title: "Config", url: routes.config, icon: SlidersHorizontal, tourId: "tour-nav-config" },
]

export function AppSidebar() {
  const { pathname } = useLocation()
  const { theme, setTheme } = useTheme()
  const { state, toggleSidebar } = useSidebar()

  return (
    <Sidebar collapsible="icon">
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg" asChild className="h-auto py-3">
              <Link to={routes.runs} className="group-data-[collapsible=icon]:justify-center">
                <EtusLogo className="size-8! shrink-0 text-primary group-data-[collapsible=icon]:size-7!" />
                <span className="text-[1.0625rem] font-mono font-black group-data-[collapsible=icon]:hidden">ETUS</span>
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel>Navigation</SidebarGroupLabel>
          <SidebarMenu>
            {navItems.map((item) => {
              const isActive =
                pathname === item.url ||
                pathname.startsWith(item.url + "/")
              return (
                <SidebarMenuItem key={item.title}>
                  <SidebarMenuButton
                    asChild
                    isActive={isActive}
                    tooltip={item.title}
                  >
                    <Link to={item.url} data-tour-id={item.tourId}>
                      <item.icon />
                      <span>{item.title}</span>
                    </Link>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              )
            })}
          </SidebarMenu>
        </SidebarGroup>
      </SidebarContent>
      <SidebarFooter>
        <SidebarMenu>

        </SidebarMenu>
        <SidebarSeparator className="-mx-2" style={{ width: "calc(100% + 1rem)" }} />
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton
              onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
              tooltip="Toggle theme"
            >
              {theme === "dark" ? <Sun className="size-4" /> : <Moon className="size-4" />}
              <span>{theme === "dark" ? "Light Mode" : "Dark Mode"}</span>
            </SidebarMenuButton>
          </SidebarMenuItem>
          <SidebarMenuItem>
            <SidebarMenuButton
              onClick={toggleSidebar}
              tooltip={state === "expanded" ? "Collapse sidebar" : "Expand sidebar"}
            >
              {state === "expanded"
                ? <ChevronLeft className="size-4" />
                : <ChevronRight className="size-4" />}
              <span>Collapse</span>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}
