const express = require("express");
const { Sequelize, DataTypes } = require("sequelize");

const app = express();
app.use(express.json());


const port = 3000;

const sequelize = new Sequelize("test_db", "root", "root", {
  host: "db", // 'db' is the service name from docker-compose.yml
  dialect: "mysql",
});

const User = sequelize.define("User", {
  name: DataTypes.STRING,
  email: DataTypes.STRING,
  age: DataTypes.INTEGER
});

app.get("/users", async (req, res) => {
  try {
    const users = await User.findAll();
    res.json(users);
  } catch (err) {
    console.error(err);
  }
});

app.post("/users", async (req, res) => {
  try {
    const { name, email, age } = req.body;
    const user = await User.create({ name, email, age });
    res.status(201).json(user);
  } catch (err) {
    console.error(err);
    res.status(400).json({ error: "Failed to create user" });
  }
});

app.listen(port, () => {
  console.log(`App running on http://localhost:${port}`);
});
