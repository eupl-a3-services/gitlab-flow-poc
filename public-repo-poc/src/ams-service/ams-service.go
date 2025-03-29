package main

import (
	"os"
	"os/exec"
	"regexp"
	"strings"
	"fmt"
	"net"
	"net/http"
)

var (
    AMS_NAME     string
    AMS_REVISION string
    AMS_BUILD    string
)

func check(e error) {
	if e != nil {
		panic(e)
	}
}

func main() {
	fmt.Println("====================== [ " + AMS_NAME + " | " + AMS_REVISION + " | " + AMS_BUILD +" ]")
	fmt.Println("AMS: "          + os.Getenv("AMS"))
	fmt.Println("AMS_NAME: "     + os.Getenv("AMS_NAME"))
	fmt.Println("AMS_REVISION: " + os.Getenv("AMS_REVISION"))
	fmt.Println("AMS_DEPLOY: "   + os.Getenv("AMS_DEPLOY"))
	fmt.Println("AMS_ENV: "      + os.Getenv("AMS_ENV"))
	fmt.Println("======================")
	fmt.Println("AMS_HOME: "     + os.Getenv("AMS_HOME"))
	fmt.Println("AMS_CMD: "      + os.Getenv("AMS_CMD"))
	fmt.Println("AMS_PORT: "     + os.Getenv("AMS_PORT"))
	fmt.Println("AMS_BIND: "     + os.Getenv("AMS_BIND"))
	fmt.Println("======================")
	svg := retrieveSvg()
	fmt.Println(svg)
	fmt.Println("======================")
	//saveSvg(svg)
	//runCommand("/portainer")
	//listenAndServe(svg, 5433)
	//os.Getenv("AMS_HOME")

	if(os.Getenv("AMS_HOME") != ""){
		fmt.Println("AMS_HOME")
		saveSvg(svg, os.Getenv("AMS_HOME"))
	}
	if(os.Getenv("AMS_CMD") != ""){
		fmt.Println("AMS_CMD")
		runCommand(os.Getenv("AMS_CMD"))
	}
	if(os.Getenv("AMS_PORT") != ""){
		fmt.Println("AMS_PORT")
		listenAndServe(svg, os.Getenv("AMS_PORT"))
	}
	if(os.Getenv("AMS_BIND") != ""){
		fmt.Println("AMS_BIND")
		listenAndCheck(svg, os.Getenv("AMS_BIND"))
	}
}

func listenAndServe(svg string, port string){
	fmt.Println("listenAndServe '/ams' " + port)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/ams", http.StatusMovedPermanently)
	})
	http.HandleFunc("/ams", func(w http.ResponseWriter, r *http.Request){
		w.Header().Add("Content-Type", "image/svg+xml")
		fmt.Fprintf(w, svg)
	})
	http.ListenAndServe(":" + port, nil)
	return 
}

func listenAndCheck(svg string, ports string){
	portsA := strings.Split(ports, ":")
	listen := portsA[0]
	check := portsA[1]
	fmt.Println("ListenAndCheck '/ams' listen: " + listen + ", check: " + check)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/ams", http.StatusMovedPermanently)
	})
	http.HandleFunc("/ams", func(w http.ResponseWriter, r *http.Request){
		ln, err := net.Listen("tcp", ":" + check)	
		if err != nil {
			w.Header().Add("Content-Type", "image/svg+xml")
			fmt.Fprintf(w, svg)
		} else {
			http.Error(w, "There is no service on the port " + check, 406)
			ln.Close()
		}
	})
	http.ListenAndServe(":" + listen, nil)
	return 
}

func runCommand(command string) {
	fmt.Println("Starting " + command)
	cmd := exec.Command(command)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	if err != nil {
		fmt.Println("ERROR!!! cmd.Run() failed with %s\n", err)
	}
	fmt.Println("DONE " + command)
	return
}

func saveSvg(svg string, home string) () {
	fmt.Println("Save svg")
	d1 := []byte(svg)
	err := os.WriteFile(home+"/"+"ams.svg", d1, 0644)
	check(err)
	return
}

func retrieveSvg() (svg string) {
	svg = os.Getenv("AMS")

	pat := regexp.MustCompile(`\${([^}]+)}`)
	matches := pat.FindAllStringSubmatch(svg, -1) // matches is [][]string

	for _, match := range matches {
		//fmt.Printf("key=%s, value=%s, env=%s\n", match[0], match[1], os.Getenv(match[1]))
		replacer := strings.NewReplacer(match[0], os.Getenv(match[1]))
		svg = replacer.Replace(svg)
	}
	return
}