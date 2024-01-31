from bs4 import BeautifulSoup
import requests
from selenium import webdriver
import os

# URL = "https://superbet.ro/bilet/895F-Z7WQNI"
URL = "http://superbet.ro"

driver = webdriver.Chrome()
driver.get(URL)

bilet = driver.page_source

#print(driver)


# page = requests.get(URL)

soup = BeautifulSoup(bilet)

#result = soup.find(id="app")

job_elements = soup.find("div", class_="tickets-stack__content")

#print(result.prettify())
# print(soup.prettify())

print(job_elements.text)